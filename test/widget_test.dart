import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brightbrush/app.dart';
import 'package:brightbrush/core/firebase/firebase_providers.dart';
import 'package:brightbrush/core/settings/shared_preferences_provider.dart';

void main() {
  testWidgets('Login screen shows demo access for every role', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // The router awaits anonymous sign-in before leaving splash;
          // `flutter test` has no real Firebase platform channels, so a
          // fake auth instance stands in for it.
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
        ],
        child: const BrightBrushApp(),
      ),
    );

    // Splash screen redirects to /login once no role is signed in.
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsNWidgets(2)); // headline + submit button
    expect(find.text('Continue as Guest Customer'), findsOneWidget);
    expect(find.text('Continue as Delivery Staff (demo)'), findsOneWidget);
    expect(find.text('Continue as System Manager (demo)'), findsOneWidget);
    expect(find.text('Continue as Admin / CEO (demo)'), findsOneWidget);
  });
}
