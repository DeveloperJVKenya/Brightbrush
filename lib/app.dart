import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/connectivity/connection_banner.dart';
import 'core/l10n/current_l10n.dart';
import 'core/l10n/language.dart';
import 'core/l10n/language_sync.dart';
import 'core/router/app_router.dart';
import 'l10n/app_localizations.dart';
import 'core/settings/settings_providers.dart';
import 'core/theme/app_theme.dart';

class BrightBrushApp extends ConsumerWidget {
  const BrightBrushApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final font = ref.watch(appFontProvider);
    final textScale = ref.watch(textScaleProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'BrightBrush Creations',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(fontFamily: font.fontFamily),
      darkTheme: AppTheme.dark(fontFamily: font.fontFamily),
      routerConfig: router,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: CurrentL10nScope(
            child: LanguageSync(child: ConnectionBannerHost(child: child!)),
          ),
        );
      },
    );
  }
}
