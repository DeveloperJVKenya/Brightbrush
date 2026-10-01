import 'dart:async';

import '../l10n/current_l10n.dart';

/// Firestore keeps writes made while offline and sends them when the
/// connection returns, but on the web the returned future only completes
/// once the server confirms. While the device is offline, stop waiting after
/// a moment so the screen can move on — the change is already saved on the
/// device and will sync. Online, this simply waits for the write.
Future<T?> queuedWrite<T>(Future<T> write) {
  if (!appIsOffline) return write;
  return write
      .then<T?>((v) => v)
      .timeout(const Duration(seconds: 2), onTimeout: () => null);
}
