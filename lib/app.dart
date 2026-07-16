import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
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

    return MaterialApp.router(
      title: 'BrightBrush Creations',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(fontFamily: font.fontFamily),
      darkTheme: AppTheme.dark(fontFamily: font.fontFamily),
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        );
      },
    );
  }
}
