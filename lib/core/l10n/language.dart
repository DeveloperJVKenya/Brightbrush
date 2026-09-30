import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/orders/domain/order_status.dart';
import '../../l10n/app_localizations.dart';
import '../settings/shared_preferences_provider.dart';

/// App language (English / Kiswahili), remembered per device.
class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier(this._ref)
    : super(switch (_ref.read(sharedPreferencesProvider).getString(_key)) {
        final String code => Locale(code),
        null => null,
      });

  static const _key = 'appLanguage';
  final Ref _ref;

  void set(Locale? locale) {
    state = locale;
    final prefs = _ref.read(sharedPreferencesProvider);
    if (locale == null) {
      prefs.remove(_key);
    } else {
      prefs.setString(_key, locale.languageCode);
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>(
  (ref) => LocaleNotifier(ref),
);

class LanguageTile extends ConsumerWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return ListTile(
      leading: const Icon(Icons.translate_rounded),
      title: Text(AppLocalizations.of(context).language),
      trailing: DropdownButton<String?>(
        value: locale?.languageCode,
        items: const [
          DropdownMenuItem(value: null, child: Text('Auto')),
          DropdownMenuItem(value: 'en', child: Text('English')),
          DropdownMenuItem(value: 'sw', child: Text('Kiswahili')),
        ],
        onChanged: (v) =>
            ref.read(localeProvider.notifier).set(v == null ? null : Locale(v)),
      ),
    );
  }
}

extension OrderStatusL10n on OrderStatus {
  String localized(BuildContext context) {
    final l = AppLocalizations.of(context);
    return switch (this) {
      OrderStatus.pendingReview => l.statusPendingReview,
      OrderStatus.confirmed => l.statusConfirmed,
      OrderStatus.awaitingProof => l.statusAwaitingProof,
      OrderStatus.inProduction => l.statusInProduction,
      OrderStatus.qualityCheck => l.statusQualityCheck,
      OrderStatus.readyForDelivery => l.statusReadyForDelivery,
      OrderStatus.outForDelivery => l.statusOutForDelivery,
      OrderStatus.completed => l.statusCompleted,
      OrderStatus.cancelled => l.statusCancelled,
    };
  }
}

/// Customer navigation labels by route (staff shells stay in English).
String? localizedModuleLabel(BuildContext context, String path) {
  final l = AppLocalizations.of(context);
  return switch (path) {
    '/customer' => l.navHome,
    '/customer/packages' => l.navPackages,
    '/customer/portfolio' => l.navPortfolio,
    '/customer/orders' => l.navOrders,
    '/customer/tracking' => l.navTracking,
    '/customer/cart' => l.navCart,
    '/customer/notifications' => l.navNotifications,
    '/customer/support' => l.navSupport,
    '/customer/profile' => l.navProfile,
    _ => null,
  };
}
