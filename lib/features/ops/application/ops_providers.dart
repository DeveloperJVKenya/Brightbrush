import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../assets/application/assets_providers.dart';
import '../../assets/domain/company_asset.dart';
import '../data/ops_repository.dart';

final opsRepositoryProvider = Provider<OpsRepository>((ref) {
  return OpsRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
    ref.watch(firebaseFunctionsProvider),
  );
});

final productionJobsProvider = StreamProvider<List<ProductionJob>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(opsRepositoryProvider).streamJobs();
});

/// Machines (CompanyAssets in the 'machine' category) for scheduling.
final machinesProvider = Provider<List<CompanyAsset>>((ref) {
  final all = ref.watch(allAssetsProvider).valueOrNull ?? const [];
  return all
      .where(
        (a) =>
            a.category == AssetCategory.machine &&
            a.condition != AssetCondition.retired,
      )
      .toList();
});

final orderEventsProvider = StreamProvider.autoDispose
    .family<List<OrderEvent>, String>((ref, orderId) {
      return ref.watch(opsRepositoryProvider).streamEvents(orderId);
    });

final deliveryCodeProvider = StreamProvider.autoDispose.family<String?, String>(
  (ref, orderId) {
    return ref.watch(opsRepositoryProvider).streamDeliveryCode(orderId);
  },
);

final inventoryMovementsProvider = StreamProvider<List<InventoryMovement>>((
  ref,
) {
  ref.watch(authStateProvider);
  return ref.watch(opsRepositoryProvider).streamMovements();
});

final purchaseOrdersProvider = StreamProvider<List<PurchaseOrder>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(opsRepositoryProvider).streamPurchaseOrders();
});

final auditLogProvider = StreamProvider<List<AuditEntry>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(opsRepositoryProvider).streamAudit();
});
