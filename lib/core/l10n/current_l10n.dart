import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// The app's current translations, for code with no BuildContext (error
/// messages, notifications built in services). Kept up to date by the
/// MaterialApp builder in app.dart.
AppLocalizations get l10nNow =>
    _current ?? lookupAppLocalizations(const Locale('en'));

AppLocalizations? _current;

/// True while the connection monitor says the device can't reach the
/// internet (set by ConnectionBannerHost).
bool appIsOffline = false;

/// Records the translations for the locale the app is showing.
class CurrentL10nScope extends StatelessWidget {
  const CurrentL10nScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    _current = AppLocalizations.of(context);
    // Dates (DateFormat without an explicit locale) follow the app language,
    // e.g. "12 Okt 2026" in Kiswahili.
    Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
    return child;
  }
}
