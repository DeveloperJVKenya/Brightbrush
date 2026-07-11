import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brightbrush/app.dart';

void main() {
  testWidgets('Login screen shows demo access for every role', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BrightBrushApp()));

    // Splash screen redirects to /login once no role is signed in.
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsNWidgets(2)); // headline + disabled submit button
    expect(find.text('Continue as Customer'), findsOneWidget);
    expect(find.text('Continue as Delivery Staff'), findsOneWidget);
    expect(find.text('Continue as System Manager'), findsOneWidget);
    expect(find.text('Continue as Admin / CEO'), findsOneWidget);
  });
}
