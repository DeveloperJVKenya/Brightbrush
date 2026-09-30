import 'package:brightbrush/core/auth/app_role.dart';
import 'package:brightbrush/core/auth/auth_providers.dart';
import 'package:brightbrush/core/firebase/firebase_providers.dart';
import 'package:brightbrush/features/admin/presentation/role_management_screen.dart';
import 'package:brightbrush/features/auth/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _joined = DateTime(2026, 9, 1);

UserProfile _profile(
  String uid,
  String name,
  String email,
  AppRole role, {
  bool disabled = false,
}) => UserProfile(
  uid: uid,
  email: email,
  displayName: name,
  role: role,
  createdAt: _joined,
  updatedAt: _joined,
  phone: '0712345678',
  photoUrl: null,
  dailyWage: null,
  vehiclePlate: '',
  availability: true,
  disabled: disabled,
);

final _profiles = [
  _profile('r1', 'Real Rider', 'rider@gmail.com', AppRole.deliveryStaff),
  _profile('r2', 'Real Shopper', 'shopper@gmail.com', AppRole.user),
  _profile('r3', 'Real Boss', 'boss@gmail.com', AppRole.admin, disabled: true),
  _profile(
    'd1',
    'Peter Mwangi',
    'peter.mwangi@brightbrush.demo',
    AppRole.deliveryStaff,
  ),
];

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allUserProfilesProvider.overrideWith((ref) => Stream.value(_profiles)),
        currentUidProvider.overrideWithValue('r2'),
      ],
      child: const MaterialApp(home: Scaffold(body: RoleManagementScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('seeded accounts are recognised as demo', () {
    expect(_profiles.where((p) => p.isDemo).map((p) => p.uid), ['d1']);
  });

  testWidgets('real and demo accounts live on separate tabs', (tester) async {
    await _pump(tester);
    expect(find.text('Real users (3)'), findsOneWidget);
    expect(find.text('Demo accounts (1)'), findsOneWidget);
    expect(find.text('Real Rider'), findsOneWidget);
    expect(find.text('Peter Mwangi'), findsNothing);

    await tester.tap(find.text('Demo accounts (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Peter Mwangi'), findsOneWidget);
    expect(find.text('Real Rider'), findsNothing);
  });

  testWidgets('role chips filter the real tab', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Delivery Staff (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Real Rider'), findsOneWidget);
    expect(find.text('Real Shopper'), findsNothing);

    await tester.ensureVisible(find.text('Suspended (1)'));
    await tester.tap(find.text('Suspended (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Real Boss'), findsOneWidget);
    expect(find.text('Real Rider'), findsNothing);
  });

  testWidgets('user actions menu offers management and contact actions', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Account actions').first);
    await tester.pumpAndSettle();
    for (final label in [
      'View details',
      'Change role...',
      'Revoke to User',
      'Set daily wage...',
      'WhatsApp',
      'Call',
      'Send email',
      'Copy uid',
      'Suspend account',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
