import 'package:brightbrush/core/connectivity/connection_banner.dart';
import 'package:brightbrush/core/connectivity/connection_status.dart';
import 'package:brightbrush/core/errors/server_messages.dart';
import 'package:brightbrush/core/errors/user_facing_error.dart';
import 'package:brightbrush/core/l10n/current_l10n.dart';
import 'package:brightbrush/l10n/app_localizations.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed connection state, without the real network monitor.
class _FakeConnection extends ConnectionStatusNotifier {
  _FakeConnection(this.initial);

  final ConnectionInfo initial;

  @override
  ConnectionInfo build() => initial;

  @override
  Future<void> check() async {}
}

Future<void> _pump(
  WidgetTester tester, {
  required ConnectionInfo info,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectionStatusProvider.overrideWith(() => _FakeConnection(info)),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => CurrentL10nScope(
          child: ConnectionBannerHost(child: child!),
        ),
        home: const Scaffold(body: Center(child: Text('Saved catalog'))),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('offline shows a tag over the page, not instead of it', (
    tester,
  ) async {
    await _pump(
      tester,
      info: const ConnectionInfo(quality: NetQuality.offline, hasNetwork: false),
    );
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.textContaining('Turn on Wi-Fi or mobile data'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    // The page itself is still there.
    expect(find.text('Saved catalog'), findsOneWidget);
    expect(appIsOffline, isTrue);
  });

  testWidgets('connected without internet explains the data/Wi-Fi problem', (
    tester,
  ) async {
    await _pump(
      tester,
      info: const ConnectionInfo(quality: NetQuality.offline, hasNetwork: true),
    );
    expect(find.textContaining("internet isn't reachable"), findsOneWidget);
  });

  testWidgets('weak connection can be dismissed', (tester) async {
    await _pump(tester, info: const ConnectionInfo(quality: NetQuality.weak));
    expect(find.text('Weak connection'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Weak connection'), findsNothing);
    expect(find.text('Saved catalog'), findsOneWidget);
  });

  testWidgets('online shows no bar', (tester) async {
    await _pump(tester, info: const ConnectionInfo(quality: NetQuality.online));
    expect(find.text("You're offline"), findsNothing);
    expect(find.text('Weak connection'), findsNothing);
    expect(appIsOffline, isFalse);
  });

  testWidgets('Kiswahili: offline bar, offline errors and server messages', (
    tester,
  ) async {
    await _pump(
      tester,
      info: const ConnectionInfo(quality: NetQuality.offline, hasNetwork: false),
      locale: const Locale('sw'),
    );
    expect(find.text('Uko nje ya mtandao'), findsOneWidget);

    // Any network-looking failure while offline gets the offline message.
    expect(
      friendlyError(FirebaseFunctionsException(code: 'unavailable', message: 'x')),
      'Uko nje ya mtandao. Unganisha intaneti kisha ujaribu tena.',
    );

    expect(translateServerMessage('Your cart is empty.'), 'Kikapu chako ni kitupu.');
    expect(
      translateServerMessage('"Polo shirt" has a minimum order of 50. You have 12.'),
      '"Polo shirt" ina kiwango cha chini cha 50. Una 12.',
    );
    expect(
      translateServerMessage('Contact name must be between 2 and 80 characters.'),
      'Jina la mawasiliano lazima iwe na herufi kati ya 2 na 80.',
    );
    expect(
      translateServerMessage('Left chest: add artwork or text.'),
      'Kifua cha kushoto: ongeza nembo au maandishi.',
    );
    // Unknown messages stay in English rather than being garbled.
    expect(translateServerMessage('Something brand new.'), 'Something brand new.');
  });

  testWidgets('English messages pass through unchanged', (tester) async {
    await _pump(tester, info: const ConnectionInfo(quality: NetQuality.online));
    expect(translateServerMessage('Your cart is empty.'), 'Your cart is empty.');
  });
}
