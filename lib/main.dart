import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
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
    webProvider: ReCaptchaEnterpriseProvider(
      '6LeR-7wtAAAAADqJWHzTD9nug4Rz9ZG6V3yCYa5f',
    ),
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const BrightBrushApp(),
    ),
  );
}
