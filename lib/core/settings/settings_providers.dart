import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_font.dart';
import 'shared_preferences_provider.dart';

const _themeModeKey = 'settings.themeMode';
const _fontKey = 'settings.font';

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_themeModeKey);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(sharedPreferencesProvider).setString(_themeModeKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class AppFontController extends Notifier<AppFont> {
  @override
  AppFont build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_fontKey);
    return AppFont.fromName(raw);
  }

  void set(AppFont font) {
    state = font;
    ref.read(sharedPreferencesProvider).setString(_fontKey, font.name);
  }
}

final appFontProvider = NotifierProvider<AppFontController, AppFont>(AppFontController.new);
