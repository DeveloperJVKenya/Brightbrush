import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/customization_repository.dart';
import '../domain/artwork.dart';
import '../domain/customization_pricing.dart';

final customizationRepositoryProvider = Provider<CustomizationRepository>((
  ref,
) {
  return CustomizationRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
  );
});

final myArtworksProvider = StreamProvider<List<Artwork>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(customizationRepositoryProvider).streamMyArtworks(uid);
});

final allArtworksProvider = StreamProvider<List<Artwork>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(customizationRepositoryProvider).streamAllArtworks();
});

final decorationPricingProvider = StreamProvider<DecorationPricing>((ref) {
  return ref.watch(customizationRepositoryProvider).streamDecorationPricing();
});
