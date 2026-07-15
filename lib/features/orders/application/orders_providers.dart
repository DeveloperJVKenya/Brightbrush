import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/maps/maps_config.dart';
import '../data/geocoding_service.dart';
import '../data/orders_repository.dart';
import '../domain/order_model.dart';
import '../domain/order_status.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(firestoreProvider));
});

final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService(googleMapsApiKey);
});

/// The signed-in customer's own orders, live-updating.
final myOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(ordersRepositoryProvider).streamForCustomer(uid);
});

/// Every order in the system — Manager/Admin/Delivery Staff all read from
/// this; each role's screen filters client-side rather than adding more
/// composite indexes for a pilot's order volume.
///
/// Watches [authStateProvider] purely so this listener gets torn down and
/// re-created whenever the signed-in user changes (e.g. switching role):
/// without that, the underlying Firestore subscription keeps running under
/// the *old* auth context, and the moment that token is no longer valid for
/// the query, Firestore surfaces it as a live permission-denied error on an
/// otherwise-idle screen instead of the listener just being replaced.
final allOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(ordersRepositoryProvider).streamAll();
});

/// Ready for delivery, nobody's claimed it yet — the Delivery Staff queue.
final availableForDeliveryProvider = Provider<AsyncValue<List<OrderModel>>>((ref) {
  return ref.watch(allOrdersProvider).whenData(
        (orders) => orders
            .where((o) => o.status == OrderStatus.readyForDelivery && o.assignedStaffId == null)
            .toList(),
      );
});

/// This delivery staff member's in-progress deliveries.
final myActiveDeliveriesProvider = Provider<AsyncValue<List<OrderModel>>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(allOrdersProvider).whenData(
        (orders) => orders
            .where((o) => o.status == OrderStatus.outForDelivery && o.assignedStaffId == uid)
            .toList(),
      );
});

/// This delivery staff member's completed delivery history.
final myDeliveryHistoryProvider = Provider<AsyncValue<List<OrderModel>>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(allOrdersProvider).whenData(
        (orders) => orders.where((o) => o.status == OrderStatus.completed && o.assignedStaffId == uid).toList(),
      );
});
