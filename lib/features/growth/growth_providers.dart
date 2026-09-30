import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/logging/stream_error_logger.dart';

// ------------------------------------------------------------ Addresses

class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.contactName,
    required this.contactPhone,
    this.lat,
    this.lng,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String address;
  final String contactName;
  final String contactPhone;
  final double? lat;
  final double? lng;
  final bool isDefault;

  bool get hasPin => lat != null && lng != null;

  factory SavedAddress.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return SavedAddress(
      id: doc.id,
      label: d['label'] as String? ?? '',
      address: d['address'] as String? ?? '',
      contactName: d['contactName'] as String? ?? '',
      contactPhone: d['contactPhone'] as String? ?? '',
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      isDefault: d['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'label': label,
    'address': address,
    'contactName': contactName,
    'contactPhone': contactPhone,
    'lat': lat,
    'lng': lng,
    'isDefault': isDefault,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

CollectionReference<Map<String, dynamic>> _addresses(Ref ref, String uid) => ref
    .read(firestoreProvider)
    .collection('Users')
    .doc(uid)
    .collection('Addresses');

final savedAddressesProvider = StreamProvider<List<SavedAddress>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('Users')
      .doc(uid)
      .collection('Addresses')
      .snapshots()
      .map(
        (s) => s.docs.map(SavedAddress.fromFirestore).toList()
          ..sort(
            (a, b) => (b.isDefault ? 1 : 0).compareTo(a.isDefault ? 1 : 0),
          ),
      )
      .transform(logStreamErrors('[addresses] stream failed'));
});

class AddressActions {
  AddressActions(this._ref);

  final Ref _ref;

  Future<void> save(SavedAddress a) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    final col = _addresses(_ref, uid);
    if (a.id.isEmpty) {
      await col.add(a.toMap());
    } else {
      await col.doc(a.id).set(a.toMap());
    }
  }

  Future<void> delete(String id) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    await _addresses(_ref, uid).doc(id).delete();
  }
}

final addressActionsProvider = Provider<AddressActions>(
  (ref) => AddressActions(ref),
);

// -------------------------------------------------------------- Loyalty

class LoyaltySettings {
  const LoyaltySettings({
    this.enabled = false,
    this.pointsPerHundred = 1,
    this.pointValue = 1,
    this.referralBonusPoints = 200,
    this.maxRedeemPercent = 20,
  });

  final bool enabled;
  final num pointsPerHundred;
  final num pointValue;
  final num referralBonusPoints;
  final num maxRedeemPercent;

  factory LoyaltySettings.fromMap(Map<String, dynamic>? d) => LoyaltySettings(
    enabled: d?['enabled'] as bool? ?? false,
    pointsPerHundred: d?['pointsPerHundred'] as num? ?? 1,
    pointValue: d?['pointValue'] as num? ?? 1,
    referralBonusPoints: d?['referralBonusPoints'] as num? ?? 200,
    maxRedeemPercent: d?['maxRedeemPercent'] as num? ?? 20,
  );

  Map<String, dynamic> toFirestore(String uid) => {
    'enabled': enabled,
    'pointsPerHundred': pointsPerHundred,
    'pointValue': pointValue,
    'referralBonusPoints': referralBonusPoints,
    'maxRedeemPercent': maxRedeemPercent,
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  };

  /// Mirror of `redeemable` in functions/src/loyalty/loyalty.ts (preview).
  ({int points, num value}) redeemable(
    int balance,
    num subtotalAfterDiscounts,
  ) {
    if (!enabled || pointValue <= 0) return (points: 0, value: 0);
    final cap = (subtotalAfterDiscounts * maxRedeemPercent / 100).floor();
    final maxPoints = (cap / pointValue).floor();
    final points = balance < maxPoints ? balance : maxPoints;
    return (
      points: points < 0 ? 0 : points,
      value: (points * pointValue).round(),
    );
  }
}

final loyaltySettingsProvider = StreamProvider<LoyaltySettings>(
  (ref) => ref
      .watch(firestoreProvider)
      .collection('Settings')
      .doc('loyalty')
      .snapshots()
      .map((s) => LoyaltySettings.fromMap(s.data()))
      .handleError((Object _) => const LoyaltySettings()),
);

final myPointsProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(0);
  return ref
      .watch(firestoreProvider)
      .collection('LoyaltyAccounts')
      .doc(uid)
      .snapshots()
      .map((s) => (s.data()?['points'] as num?)?.toInt() ?? 0)
      .handleError((Object _) => 0);
});

// ------------------------------------------------------------- Wishlist

final wishlistProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const {});
  return ref
      .watch(firestoreProvider)
      .collection('Users')
      .doc(uid)
      .collection('Wishlist')
      .snapshots()
      .map((s) => s.docs.map((d) => d.id).toSet())
      .handleError((Object _) => <String>{});
});

Future<void> toggleWishlist(WidgetRef ref, String itemId, bool add) async {
  final uid = ref.read(currentUidProvider);
  if (uid == null) return;
  final doc = ref
      .read(firestoreProvider)
      .collection('Users')
      .doc(uid)
      .collection('Wishlist')
      .doc(itemId);
  if (add) {
    await doc.set({'addedAt': FieldValue.serverTimestamp()});
  } else {
    await doc.delete();
  }
}

// ----------------------------------------------------- Display currency

/// Display-only conversion (everything is charged in KES). Rates are KES
/// per unit, set by the admin in Settings/currency.
final currencyRatesProvider = StreamProvider<Map<String, num>>(
  (ref) => ref
      .watch(firestoreProvider)
      .collection('Settings')
      .doc('currency')
      .snapshots()
      .map(
        (s) => {
          for (final e in Map<String, dynamic>.from(
            (s.data()?['rates'] as Map?) ?? const {},
          ).entries)
            if (e.value is num && (e.value as num) > 0) e.key: e.value as num,
        },
      )
      .handleError((Object _) => <String, num>{}),
);
