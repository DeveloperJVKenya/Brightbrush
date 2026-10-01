import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brightbrush/core/firebase/firebase_providers.dart';
import 'package:brightbrush/features/auth/presentation/login_screen.dart';
import 'package:brightbrush/l10n/app_localizations.dart';

/// Guests now land on the public catalog (only acting needs an account), so
/// the login screen is pumped directly rather than via the splash redirect.
Future<void> _pumpLogin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // `flutter test` has no real Firebase platform channels.
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(signedIn: false),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Login requires a real account and offers password recovery', (
    tester,
  ) async {
    await _pumpLogin(tester);

    expect(find.text('Sign in'), findsNWidgets(2)); // headline + submit button
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text("Don't have an account? Sign up"), findsOneWidget);

    // The one-tap guest/demo shortcuts this system used to offer are gone.
    expect(find.text('Continue as Guest Customer'), findsNothing);
    expect(find.textContaining('demo'), findsNothing);
  });

  testWidgets('Sign-up asks for Terms and Privacy consent', (tester) async {
    await _pumpLogin(tester);

    await tester.tap(find.text("Don't have an account? Sign up"));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);
  });
}
