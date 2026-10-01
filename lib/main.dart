import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/firebase/firebase_providers.dart';
import 'core/monitoring/monitoring.dart';
import 'core/settings/shared_preferences_provider.dart';
import 'firebase_options.dart';

const _appCheckDebugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // App Check is enforced on every callable and on Gemini (firebaseml), so
  // every build needs a valid token. Release builds prove they're the real
  // app: reCAPTCHA Enterprise on the web (site key registered against
  // bright-brush.web.app), Play Integrity on Android, App Attest on iOS.
  // Debug builds use a debug token registered in Firebase → App Check →
  // Manage debug tokens, passed with
  //   flutter run --dart-define-from-file=app_check_debug.json
  // (a git-ignored file). Without it, the SDK prints a fresh token to the
  // log to register instead.
  final debugToken = _appCheckDebugToken.isEmpty ? null : _appCheckDebugToken;
  await FirebaseAppCheck.instance.activate(
    providerWeb: kDebugMode
        ? WebDebugProvider(debugToken: debugToken)
        : ReCaptchaEnterpriseProvider(
            '6LeR-7wtAAAAADqJWHzTD9nug4Rz9ZG6V3yCYa5f',
          ),
    providerAndroid: kDebugMode
        ? AndroidDebugProvider(debugToken: debugToken)
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? AppleDebugProvider(debugToken: debugToken)
        : const AppleAppAttestProvider(),
  );
  // Offline cache (on by default on mobile; web needs it switched on) so
  // screens open instantly and drivers keep working with a patchy signal.
  FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: firestoreDatabaseId,
  ).settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    // Web: keep the offline copy working in every open tab, not just the
    // first one.
    webPersistentTabManager: WebPersistentMultipleTabManager(),
  );
  await Monitoring.init();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const BrightBrushApp(),
    ),
  );
}
