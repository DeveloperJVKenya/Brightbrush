import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/user_facing_error.dart';
import '../application/commerce_providers.dart';

final _etimsAdminProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(commerceRepositoryProvider).adminGetEtims(),
);

/// Admin/CEO: KRA eTIMS (OSCU) connection. Steps: enter the details from
/// your eTIMS registration → Save → Initialise device (gets the
/// communication key; doubles as a connection test) → switch on.
class EtimsCard extends ConsumerStatefulWidget {
  const EtimsCard({super.key});

  @override
  ConsumerState<EtimsCard> createState() => _EtimsCardState();
}

class _EtimsCardState extends ConsumerState<EtimsCard> {
  final Map<String, TextEditingController> _c = {};
  String _mode = 'sandbox';
  bool _enabled = false;
  bool _autoSubmit = true;
  bool _seeded = false;
  bool _busy = false;

  TextEditingController _ctl(String k) =>
      _c.putIfAbsent(k, TextEditingController.new);

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _seed(Map<String, dynamic> d) {
    if (_seeded) return;
    _seeded = true;
    _mode = d['mode'] as String? ?? 'sandbox';
    _enabled = d['enabled'] as bool? ?? false;
    _autoSubmit = d['autoSubmit'] as bool? ?? true;
    for (final f in (d['fields'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(f as Map);
      _ctl(m['key'] as String).text = m['value'] as String? ?? '';
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(commerceRepositoryProvider)
          .adminSaveEtims(
            mode: _mode,
            enabled: _enabled,
            autoSubmit: _autoSubmit,
            values: {for (final e in _c.entries) e.key: e.value.text.trim()},
          );
      _snack(
        r['needsInitialize'] == true
            ? 'Saved. Now tap "Initialise device" to connect to KRA.'
            : 'eTIMS settings saved',
      );
      _seeded = false;
      ref.invalidate(_etimsAdminProvider);
    } catch (error) {
      _snack(friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _init() async {
    setState(() => _busy = true);
    try {
      final r = await ref.read(commerceRepositoryProvider).adminInitEtims();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(
            r.ok ? Icons.check_circle_rounded : Icons.error_rounded,
            color: r.ok ? Colors.green : Theme.of(context).colorScheme.error,
            size: 40,
          ),
          title: Text(r.ok ? 'Connected to KRA' : 'Initialisation failed'),
          content: Text(r.message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _seeded = false;
      ref.invalidate(_etimsAdminProvider);
    } catch (error) {
      _snack(friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(_etimsAdminProvider);
    if (async.hasValue) _seed(async.value!);
    final d = async.valueOrNull ?? const {};
    final initialized = d['initialized'] == true;
    final configured = d['configured'] == true;
    final lastTest = d['lastTest'] is Map
        ? Map<String, dynamic>.from(d['lastTest'] as Map)
        : null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.isLoading && !_seeded
            ? const Center(child: CircularProgressIndicator())
            : async.hasError
            ? Text(
                'Couldn\'t load eTIMS settings: ${friendlyError(async.error!)}',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'KRA eTIMS e-invoicing',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          d['enabled'] == true
                              ? 'Live'
                              : initialized
                              ? 'Ready — off'
                              : configured
                              ? 'Needs initialising'
                              : 'Awaiting details',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  Text(
                    'Reports each invoice to KRA through the OSCU API and prints the KRA signature and QR code on it. '
                    'Register as an OSCU taxpayer on the eTIMS portal first, and register one "branded merchandise" item to report sales under.',
                    style: theme.textTheme.bodySmall,
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        launchUrl(Uri.parse('https://etims.kra.go.ke')),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open the eTIMS portal'),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'sandbox', label: Text('Sandbox')),
                      ButtonSegment(value: 'live', label: Text('Live')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (v) => setState(() => _mode = v.first),
                  ),
                  const SizedBox(height: 8),
                  for (final f in (d['fields'] as List? ?? const []))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: _ctl((f as Map)['key'] as String),
                        decoration: InputDecoration(
                          labelText:
                              '${f['label']}${f['required'] == true ? ' *' : ''}',
                          helperText: f['help'] as String?,
                          helperMaxLines: 3,
                        ),
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Submit invoices automatically'),
                    subtitle: const Text(
                      'When an order is fully paid, or confirmed on credit terms.',
                    ),
                    value: _autoSubmit,
                    onChanged: (v) => setState(() => _autoSubmit = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('eTIMS switched on'),
                    subtitle: Text(
                      initialized
                          ? 'Takes effect when you save.'
                          : 'Initialise the device first.',
                    ),
                    value: _enabled && initialized,
                    onChanged: initialized
                        ? (v) => setState(() => _enabled = v)
                        : null,
                  ),
                  if (lastTest != null)
                    Text(
                      'Last check: ${lastTest['message']}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: lastTest['ok'] == true
                            ? Colors.green
                            : theme.colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy || !configured ? null : _init,
                        icon: const Icon(Icons.power_settings_new_rounded),
                        label: const Text('Initialise device / test'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
