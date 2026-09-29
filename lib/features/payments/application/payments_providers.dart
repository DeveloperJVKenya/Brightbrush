import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/payments_repository.dart';
import '../domain/business_settings.dart';
import '../domain/payment_models.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseFunctionsProvider),
  );
});

/// Public business settings (VAT, delivery, deposits). Falls back to the
/// defaults while loading so checkout can always render a preview.
final businessSettingsProvider = StreamProvider<BusinessSettings>((ref) {
  return ref.watch(paymentsRepositoryProvider).streamBusinessSettings();
});

final paymentGatewaysProvider = StreamProvider<List<PaymentGatewayInfo>>((ref) {
  return ref.watch(paymentsRepositoryProvider).streamGateways();
});

/// Only the gateways a customer can actually use right now.
final availableGatewaysProvider = Provider<List<PaymentGatewayInfo>>((ref) {
  final all = ref.watch(paymentGatewaysProvider).valueOrNull ?? const [];
  return all.where((g) => g.isAvailable).toList();
});

/// Payment attempts on one order. Customers are scoped to their own uid (a
/// rules requirement); staff see every attempt.
final orderPaymentsProvider = StreamProvider.autoDispose
    .family<List<PaymentRecord>, ({String orderId, bool asStaff})>((ref, args) {
      final uid = ref.watch(currentUidProvider);
      if (uid == null) return Stream.value(const []);
      return ref
          .watch(paymentsRepositoryProvider)
          .streamForOrder(args.orderId, customerId: args.asStaff ? null : uid);
    });
