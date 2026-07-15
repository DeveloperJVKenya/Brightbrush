import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brightbrush/app.dart';
import 'package:brightbrush/core/firebase/firebase_providers.dart';
import 'package:brightbrush/core/settings/shared_preferences_provider.dart';

void main() {
  testWidgets('Login screen requires a real account — no guest/demo shortcuts', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // `flutter test` has no real Firebase platform channels; a signed-
          // out fake auth instance stands in so the router resolves role =
          // null and lands on /login, same as a real signed-out visitor.
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(signedIn: false)),
        ],
        child: const BrightBrushApp(),
      ),
    );

    // Splash screen redirects to /login once no role is signed in.
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsNWidgets(2)); // headline + submit button
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text("Don't have an account? Sign up"), findsOneWidget);

    // The one-tap guest/demo shortcuts this system used to offer are gone —
    // every role now requires a real, provisioned account.
    expect(find.text('Continue as Guest Customer'), findsNothing);
    expect(find.textContaining('demo'), findsNothing);
  });
}
