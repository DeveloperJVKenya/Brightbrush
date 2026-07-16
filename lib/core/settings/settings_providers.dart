import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_font.dart';
import 'shared_preferences_provider.dart';

const _themeModeKey = 'settings.themeMode';
const _fontKey = 'settings.font';
const _textScaleKey = 'settings.textScale';
const _reduceMotionKey = 'settings.reduceMotion';
const _inAppNotificationsKey = 'settings.inAppNotifications';

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

/// Accessibility text scale — a plain multiplier applied via
/// `MediaQuery.withClampedTextScaling` at the app root (see `lib/app.dart`),
/// independent of the OS's own text-scale setting.
class TextScaleController extends Notifier<double> {
  static const double min = 0.85;
  static const double max = 1.3;

  @override
  double build() {
    final raw = ref.read(sharedPreferencesProvider).getDouble(_textScaleKey);
    return raw ?? 1.0;
  }

  void set(double scale) {
    state = scale.clamp(min, max);
    ref.read(sharedPreferencesProvider).setDouble(_textScaleKey, state);
  }
}

final textScaleProvider = NotifierProvider<TextScaleController, double>(TextScaleController.new);

/// Skips the small entrance/stagger animations (e.g. `StaggeredEntrance`)
/// for anyone who finds them distracting — independent of the OS-level
/// "reduce motion" accessibility setting, which this app doesn't currently
/// read.
class ReduceMotionController extends Notifier<bool> {
  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(_reduceMotionKey) ?? false;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(_reduceMotionKey, value);
  }
}

final reduceMotionProvider = NotifierProvider<ReduceMotionController, bool>(ReduceMotionController.new);

/// Whether the Announcement banner / Notifications feed show up at all.
/// Explicitly "in-app" — there's no push notification infrastructure (FCM)
/// wired up yet, so this only ever controls what's visible while the app is
/// open, never a promise of a push alert.
class InAppNotificationsController extends Notifier<bool> {
  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(_inAppNotificationsKey) ?? true;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(_inAppNotificationsKey, value);
  }
}

final inAppNotificationsEnabledProvider =
    NotifierProvider<InAppNotificationsController, bool>(InAppNotificationsController.new);
