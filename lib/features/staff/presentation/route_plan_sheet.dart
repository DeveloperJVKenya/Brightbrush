import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_model.dart';
import '../../payments/application/payments_providers.dart';
import '../domain/route_optimizer.dart';

/// Best order to visit today's drops, starting from the shop, with a
/// one-tap multi-stop route in Google Maps.
Future<void> showRoutePlanSheet(BuildContext context, List<OrderModel> orders) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => _RoutePlanSheet(orders: orders),
  );
}

class _RoutePlanSheet extends ConsumerStatefulWidget {
  const _RoutePlanSheet({required this.orders});

  final List<OrderModel> orders;

  @override
  ConsumerState<_RoutePlanSheet> createState() => _RoutePlanSheetState();
}

class _RoutePlanSheetState extends ConsumerState<_RoutePlanSheet> {
  double? _startLat;
  double? _startLng;
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    _locateShop();
  }

  /// Starts the route at the business address (Payments & Settings), or the
  /// first stop if it can't be geocoded.
  Future<void> _locateShop() async {
    final settings = ref.read(businessSettingsProvider).valueOrNull;
    final address = settings?.pickupAddress.isNotEmpty == true
        ? settings!.pickupAddress
        : settings?.physicalAddress ?? '';
    if (address.isNotEmpty) {
      try {
        final r = await ref.read(geocodingServiceProvider).geocode(address);
        if (r != null) {
          _startLat = r.lat;
          _startLng = r.lng;
        }
      } catch (_) {
        // Fall back to starting at the first stop.
      }
    }
    if (mounted) setState(() => _locating = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapped = widget.orders
        .where((o) => o.hasDeliveryCoordinates)
        .toList();
    final missing = widget.orders.length - mapped.length;
    if (_locating) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final route = optimizeRoute(
      [for (final o in mapped) RouteStop(o, o.deliveryLat!, o.deliveryLng!)],
      startLat: _startLat,
      startLng: _startLng,
    );
    final km = routeLengthKm(route, startLat: _startLat, startLng: _startLng);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Suggested route',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${route.length} stop(s) · about ${km.toStringAsFixed(1)} km in a straight line'
            '${_startLat != null ? ' from the shop' : ''}',
            style: theme.textTheme.bodySmall,
          ),
          if (missing > 0)
            Text(
              '$missing stop(s) have no map location yet and aren\'t included.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final (i, stop) in route.indexed)
                  ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(stop.value.contactName),
                    subtitle: Text(
                      stop.value.deliveryAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: route.isEmpty
                ? null
                : () => launchUrl(
                    googleMapsRouteUrl(
                      route,
                      startLat: _startLat,
                      startLng: _startLng,
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
            icon: const Icon(Icons.navigation_rounded),
            label: Text(
              route.length > 10
                  ? 'Open first 10 stops in Google Maps'
                  : 'Start in Google Maps',
            ),
          ),
        ],
      ),
    );
  }
}
