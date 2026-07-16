import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../shared/search/search_utils.dart';
import '../data/assets_repository.dart';
import '../domain/company_asset.dart';

final assetsRepositoryProvider = Provider<AssetsRepository>((ref) {
  return AssetsRepository(ref.watch(firestoreProvider));
});

final allAssetsProvider = StreamProvider<List<CompanyAsset>>((ref) {
  ref.watch(currentUidProvider);
  return ref.watch(assetsRepositoryProvider).streamAll();
});

final assetsSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredAssetsProvider = Provider<AsyncValue<List<CompanyAsset>>>((ref) {
  final query = ref.watch(assetsSearchQueryProvider);
  return ref.watch(allAssetsProvider).whenData((assets) => filterBySearch(assets, query, (a) => a.searchFields));
});
