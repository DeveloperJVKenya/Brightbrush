import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../application/customization_providers.dart';
import '../domain/customization_options.dart';
import '../domain/customization_pricing.dart';

/// Admin/CEO: branding rates used for every customised order — per method
/// a one-off setup fee, a per-piece price by design size, and (embroidery)
/// a per-1000-stitch rate once a logo is digitized.
class DecorationPricingCard extends ConsumerStatefulWidget {
  const DecorationPricingCard({super.key});

  @override
  ConsumerState<DecorationPricingCard> createState() =>
      _DecorationPricingCardState();
}

class _DecorationPricingCardState extends ConsumerState<DecorationPricingCard> {
  final Map<String, TextEditingController> _c = {};
  final Map<DecorationMethod, bool> _enabled = {};
  bool _seeded = false;
  bool _saving = false;

  TextEditingController _ctl(String key) =>
      _c.putIfAbsent(key, TextEditingController.new);

  void _seed(DecorationPricing p) {
    if (_seeded) return;
    _seeded = true;
    _ctl('personalisation').text = '${p.personalisationFee}';
    for (final m in DecorationMethod.values) {
      final mp = p.of(m);
      _enabled[m] = mp.enabled;
      _ctl('${m.name}.setup').text = '${mp.setupFee}';
      _ctl('${m.name}.small').text = '${mp.small}';
      _ctl('${m.name}.medium').text = '${mp.medium}';
      _ctl('${m.name}.large').text = '${mp.large}';
      _ctl('${m.name}.stitch').text = '${mp.per1000Stitches}';
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  num _n(String key) => num.tryParse(_ctl(key).text.trim()) ?? 0;

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(customizationRepositoryProvider)
          .saveDecorationPricing(
            DecorationPricing(
              personalisationFee: _n('personalisation'),
              methods: {
                for (final m in DecorationMethod.values)
                  m: MethodPricing(
                    enabled: _enabled[m] ?? true,
                    setupFee: _n('${m.name}.setup'),
                    small: _n('${m.name}.small'),
                    medium: _n('${m.name}.medium'),
                    large: _n('${m.name}.large'),
                    per1000Stitches: m == DecorationMethod.embroidery
                        ? _n('${m.name}.stitch')
                        : 0,
                  ),
              },
            ),
            uid: uid,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Branding rates saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(error)),
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
    final async = ref.watch(decorationPricingProvider);
    if (async.hasValue) _seed(async.value!);
    if (async.hasError && !_seeded) _seed(DecorationPricing.defaults);
    if (!_seeded) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    Widget field(String key, String label) => SizedBox(
      width: 110,
      child: TextField(
        controller: _ctl(key),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, isDense: true),
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
              'Branding rates (KES)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Setup is charged once per design per order line (waived for already-digitized embroidery). '
              'Per-piece rates depend on design size: small ≤10 cm, medium ≤20 cm, large ≤30 cm.',
              style: theme.textTheme.bodySmall,
            ),
            for (final m in DecorationMethod.values) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Icon(m.icon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(m.label, style: theme.textTheme.titleSmall),
                  ),
                  Switch(
                    value: _enabled[m] ?? true,
                    onChanged: (v) => setState(() => _enabled[m] = v),
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  field('${m.name}.setup', 'Setup'),
                  field('${m.name}.small', 'Small /pc'),
                  field('${m.name}.medium', 'Medium /pc'),
                  field('${m.name}.large', 'Large /pc'),
                  if (m == DecorationMethod.embroidery)
                    field('${m.name}.stitch', 'Per 1000 st.'),
                ],
              ),
            ],
            const Divider(height: 24),
            field('personalisation', 'Name /pc'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save branding rates'),
            ),
          ],
        ),
      ),
    );
  }
}
