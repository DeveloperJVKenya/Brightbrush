import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/settings/shared_preferences_provider.dart';
import 'growth_providers.dart';

/// Currencies customers can see approximate prices in (charged in KES).
const displayCurrencies = ['USD', 'EUR', 'GBP', 'UGX', 'TZS', 'RWF'];

/// Admin/CEO: loyalty programme and display exchange rates.
class LoyaltyCurrencyCard extends ConsumerStatefulWidget {
  const LoyaltyCurrencyCard({super.key});

  @override
  ConsumerState<LoyaltyCurrencyCard> createState() =>
      _LoyaltyCurrencyCardState();
}

class _LoyaltyCurrencyCardState extends ConsumerState<LoyaltyCurrencyCard> {
  final _perHundred = TextEditingController();
  final _value = TextEditingController();
  final _bonus = TextEditingController();
  final _maxPct = TextEditingController();
  final Map<String, TextEditingController> _rates = {
    for (final c in displayCurrencies) c: TextEditingController(),
  };
  bool _enabled = false;
  bool _seededLoyalty = false;
  bool _seededRates = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_perHundred, _value, _bonus, _maxPct, ..._rates.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final db = ref.read(firestoreProvider);
      await db
          .collection('Settings')
          .doc('loyalty')
          .set(
            LoyaltySettings(
              enabled: _enabled,
              pointsPerHundred: num.tryParse(_perHundred.text) ?? 1,
              pointValue: num.tryParse(_value.text) ?? 1,
              referralBonusPoints: num.tryParse(_bonus.text) ?? 0,
              maxRedeemPercent: (num.tryParse(_maxPct.text) ?? 20).clamp(
                0,
                100,
              ),
            ).toFirestore(uid),
          );
      await db.collection('Settings').doc('currency').set({
        'rates': {
          for (final e in _rates.entries)
            if ((num.tryParse(e.value.text) ?? 0) > 0)
              e.key: num.parse(e.value.text),
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loyalty = ref.watch(loyaltySettingsProvider);
    final rates = ref.watch(currencyRatesProvider);
    if (loyalty.hasValue && !_seededLoyalty) {
      final l = loyalty.value!;
      _seededLoyalty = true;
      _enabled = l.enabled;
      _perHundred.text = '${l.pointsPerHundred}';
      _value.text = '${l.pointValue}';
      _bonus.text = '${l.referralBonusPoints}';
      _maxPct.text = '${l.maxRedeemPercent}';
    }
    if (rates.hasValue && !_seededRates) {
      _seededRates = true;
      for (final e in rates.value!.entries) {
        _rates[e.key]?.text = '${e.value}';
      }
    }
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    Widget field(TextEditingController c, String label, [String? help]) =>
        SizedBox(
          width: 200,
          child: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            decoration: InputDecoration(
              labelText: label,
              helperText: help,
              helperMaxLines: 2,
            ),
          ),
        );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Loyalty & referrals',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Loyalty programme on'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                field(_perHundred, 'Points per KES 100 spent'),
                field(_value, 'KES value of 1 point'),
                field(_bonus, 'Referral bonus (points each)'),
                field(_maxPct, 'Max % of an order paid with points'),
              ],
            ),
            const Divider(height: 32),
            Text(
              'Display currencies',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'KES per 1 unit. Customers can see approximate prices in these; everything is still charged in KES.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final c in displayCurrencies)
                  field(_rates[c]!, 'KES per 1 $c'),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save loyalty & currencies'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------- Customer display currency

class DisplayCurrencyNotifier extends StateNotifier<String?> {
  DisplayCurrencyNotifier(this._ref)
    : super(_ref.read(sharedPreferencesProvider).getString(_key));

  static const _key = 'displayCurrency';
  final Ref _ref;

  void set(String? code) {
    state = code;
    final prefs = _ref.read(sharedPreferencesProvider);
    if (code == null) {
      prefs.remove(_key);
    } else {
      prefs.setString(_key, code);
    }
  }
}

final displayCurrencyProvider =
    StateNotifierProvider<DisplayCurrencyNotifier, String?>(
      (ref) => DisplayCurrencyNotifier(ref),
    );

/// "≈ USD 12.40" next to a KES amount, when the customer picked a display
/// currency and the admin set its rate.
class ApproxPrice extends ConsumerWidget {
  const ApproxPrice({super.key, required this.kes, this.style});

  final num kes;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(displayCurrencyProvider);
    final rate = code == null
        ? null
        : ref.watch(currencyRatesProvider).valueOrNull?[code];
    if (code == null || rate == null || rate <= 0) {
      return const SizedBox.shrink();
    }
    final value = kes / rate;
    final fmt = NumberFormat.currency(
      symbol: '$code ',
      decimalDigits: value >= 1000 ? 0 : 2,
    );
    return Text(
      '≈ ${fmt.format(value)}',
      style: style ?? Theme.of(context).textTheme.bodySmall,
    );
  }
}

/// Settings screen row: pick a display currency.
class DisplayCurrencyTile extends ConsumerWidget {
  const DisplayCurrencyTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rates = ref.watch(currencyRatesProvider).valueOrNull ?? const {};
    if (rates.isEmpty) return const SizedBox.shrink();
    final code = ref.watch(displayCurrencyProvider);
    return ListTile(
      leading: const Icon(Icons.currency_exchange_rounded),
      title: const Text('Also show prices in'),
      subtitle: const Text('Approximate only — you pay in KES.'),
      trailing: DropdownButton<String?>(
        value: rates.containsKey(code) ? code : null,
        items: [
          const DropdownMenuItem(value: null, child: Text('KES only')),
          for (final c in rates.keys)
            DropdownMenuItem(value: c, child: Text(c)),
        ],
        onChanged: (v) => ref.read(displayCurrencyProvider.notifier).set(v),
      ),
    );
  }
}
