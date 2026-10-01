import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../features/orders/application/orders_providers.dart';
import '../../features/orders/domain/order_model.dart';
import 'empty_state.dart';
import '../../core/l10n/l10n_ext.dart';

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
  String? _selectedOrderId;

  static const _sidebarBreakpoint = 900.0;
  static const _sidebarWidth = 300.0;

  Future<void> _focusOn(OrderModel order) async {
    setState(() => _selectedOrderId = order.id);
    if (!order.hasDeliveryCoordinates) return;
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(order.deliveryLat!, order.deliveryLng!),
        14,
      ),
    );
  }

  Future<void> _geocodeIfNeeded(List<OrderModel> orders) async {
    for (final order in orders) {
      if (order.hasDeliveryCoordinates) continue;
      if (_geocodingInFlight.contains(order.id)) continue;
      _geocodingInFlight.add(order.id);
      try {
        final result = await ref
            .read(geocodingServiceProvider)
            .geocode(order.deliveryAddress);
        if (result != null) {
          await ref
              .read(ordersRepositoryProvider)
              .setDeliveryCoordinates(
                order.id,
                lat: result.lat,
                lng: result.lng,
              );
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
      return EmptyState(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        message: widget.emptyMessage,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _geocodeIfNeeded(orders),
    );

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
          onTap: widget.onMarkerTap == null
              ? null
              : () => widget.onMarkerTap!(context, order),
        ),
    };

    final initialTarget = pinned.isNotEmpty
        ? LatLng(pinned.first.deliveryLat!, pinned.first.deliveryLng!)
        : const LatLng(
            0.3476,
            32.5825,
          ); // Kampala — reasonable default center for this pilot

    final map = Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: pinned.isEmpty ? 4 : 12,
          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.locatingMoreStopS(
                          orders.length - pinned.length,
                        ),
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

    Widget stopList({EdgeInsetsGeometry padding = const EdgeInsets.all(8)}) {
      return ListView.separated(
        padding: padding,
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          final order = orders[index];
          return _StopListTile(
            order: order,
            subtitle: widget.markerLabel?.call(order) ?? order.deliveryAddress,
            selected: order.id == _selectedOrderId,
            onTap: () {
              _focusOn(order);
              widget.onMarkerTap?.call(context, order);
            },
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _sidebarBreakpoint) {
          // Google Map markers are native platform views, invisible to
          // Flutter's semantics tree — without this, a screen-reader user on
          // a narrow viewport (where the sidebar collapses) would have no
          // way at all to reach the stop list.
          return Stack(
            children: [
              map,
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'stopListFab',
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    constraints: const BoxConstraints(maxWidth: 560),
                    builder: (context) => SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.6,
                      child: stopList(),
                    ),
                  ),
                  icon: const Icon(Icons.list_alt_rounded),
                  label: Text(context.l10n.stops(orders.length)),
                ),
              ),
            ],
          );
        }
        final theme = Theme.of(context);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _sidebarWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  border: Border(
                    right: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: stopList(),
              ),
            ),
            Expanded(child: map),
          ],
        );
      },
    );
  }
}

class _StopListTile extends StatelessWidget {
  const _StopListTile({
    required this.order,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final OrderModel order;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                order.hasDeliveryCoordinates
                    ? Icons.location_on_rounded
                    : Icons.location_searching_rounded,
                size: 18,
                color: selected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.contactName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: selected
                            ? theme.colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.8,
                              )
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
