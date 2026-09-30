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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // App Check is ENFORCED on firebaseml.googleapis.com for this project, so
  // every Gemini call (ai_catalog_search_service, guide_assistant_service)
  // needs a valid token or Firebase rejects it before it reaches the model.
  // Web is the only platform actually shipped today, so it gets the real
  // reCAPTCHA Enterprise provider (site key registered against
  // bright-brush.web.app in Firebase App Check); other platforms fall back
  // to the debug provider so local builds there aren't blocked.
  await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaEnterpriseProvider(
      '6LeR-7wtAAAAADqJWHzTD9nug4Rz9ZG6V3yCYa5f',
    ),
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
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
