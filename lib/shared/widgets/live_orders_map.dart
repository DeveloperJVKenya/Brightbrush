import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../features/orders/application/orders_providers.dart';
import '../../features/orders/domain/order_model.dart';
import 'empty_state.dart';

/// Real Google Map of delivery stops, shared by the Delivery Staff Route Map
/// (their own active deliveries) and the Admin Deliveries screen (every
/// active delivery, across all staff).
///
/// Orders only ever collect a free-text delivery address at checkout, so
/// each stop is geocoded once (lazily, on first view here) and the
/// resulting lat/lng cached back onto the order — after that it's just a
/// Firestore read, not a repeated geocoding call.
class LiveOrdersMap extends ConsumerStatefulWidget {
  const LiveOrdersMap({
    super.key,
    required this.orders,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    this.markerLabel,
    this.onMarkerTap,
  });

  final List<OrderModel> orders;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  /// Optional extra line under the contact name in each marker's info
  /// window (e.g. which staff member owns that stop).
  final String Function(OrderModel order)? markerLabel;
  final void Function(BuildContext context, OrderModel order)? onMarkerTap;

  @override
  ConsumerState<LiveOrdersMap> createState() => _LiveOrdersMapState();
}

class _LiveOrdersMapState extends ConsumerState<LiveOrdersMap> {
  final Set<String> _geocodingInFlight = {};
  GoogleMapController? _mapController;

  Future<void> _geocodeIfNeeded(List<OrderModel> orders) async {
    for (final order in orders) {
      if (order.hasDeliveryCoordinates) continue;
      if (_geocodingInFlight.contains(order.id)) continue;
      _geocodingInFlight.add(order.id);
      try {
        final result = await ref.read(geocodingServiceProvider).geocode(order.deliveryAddress);
        if (result != null) {
          await ref
              .read(ordersRepositoryProvider)
              .setDeliveryCoordinates(order.id, lat: result.lat, lng: result.lng);
        }
      } catch (_) {
        // Best-effort: a failed geocode just means that one stop has no pin
        // yet; it'll retry next time this widget builds.
      } finally {
        _geocodingInFlight.remove(order.id);
      }
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.orders;

    if (orders.isEmpty) {
      return EmptyState(icon: widget.emptyIcon, title: widget.emptyTitle, message: widget.emptyMessage);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _geocodeIfNeeded(orders));

    final pinned = orders.where((o) => o.hasDeliveryCoordinates).toList();
    final markers = {
      for (final order in pinned)
        Marker(
          markerId: MarkerId(order.id),
          position: LatLng(order.deliveryLat!, order.deliveryLng!),
          infoWindow: InfoWindow(
            title: order.contactName,
            snippet: widget.markerLabel?.call(order) ?? order.deliveryAddress,
          ),
          onTap: widget.onMarkerTap == null ? null : () => widget.onMarkerTap!(context, order),
        ),
    };

    final initialTarget = pinned.isNotEmpty
        ? LatLng(pinned.first.deliveryLat!, pinned.first.deliveryLng!)
        : const LatLng(0.3476, 32.5825); // Kampala — reasonable default center for this pilot

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: initialTarget, zoom: pinned.isEmpty ? 4 : 12),
          markers: markers,
          onMapCreated: (controller) => _mapController = controller,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
        ),
        if (orders.length != pinned.length)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Locating ${orders.length - pinned.length} more stop(s)…',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
