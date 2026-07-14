import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main.dart` with a real instance obtained before `runApp`,
/// so Settings (theme mode, font) can be read synchronously on first frame
/// with no flash of the wrong appearance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main() before runApp');
});
