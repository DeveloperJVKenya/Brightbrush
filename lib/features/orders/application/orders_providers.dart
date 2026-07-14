import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/orders_repository.dart';
import '../domain/order_model.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(firestoreProvider));
});

/// The signed-in customer's own orders, live-updating.
final myOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final auth = ref.watch(ensureSignedInProvider);
  final uid = auth.value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(ordersRepositoryProvider).streamForCustomer(uid);
});

/// Every order in the system — Manager/Admin view.
final allOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(ordersRepositoryProvider).streamAll();
});
