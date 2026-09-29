import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../customization/presentation/decoration_pricing_card.dart';
import '../application/payments_providers.dart';
import '../domain/business_settings.dart';
import '../domain/payment_models.dart';

/// Admin/CEO: business settings (VAT, delivery, deposits, invoice details)
/// and payment gateway credentials. Each gateway is fully built in the
/// backend and stays hidden from customers until its credentials are saved
/// here and it is switched on.
final _adminGatewaysProvider =
    FutureProvider.autoDispose<List<GatewayAdminConfig>>((ref) {
      return ref.watch(paymentsRepositoryProvider).adminLoadGateways();
    });

class AdminPaymentsScreen extends ConsumerWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payments & Settings',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tax, delivery and deposit rules, plus the payment methods customers can use at checkout.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                const _BusinessSettingsCard(),
                const SizedBox(height: 16),
                const DecorationPricingCard(),
                const SizedBox(height: 28),
                Text(
                  'Payment gateways',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Paste the credentials from each provider\'s dashboard. Secrets are stored server-side only and are never shown again. '
                  'Use Sandbox until "Test connection" passes, then switch to Live.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                const _GatewaysSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GatewaysSection extends ConsumerWidget {
  const _GatewaysSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_adminGatewaysProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) {
        appLogger.e(
          '[payments-admin] Failed to load gateways',
          error: error,
          stackTrace: stack,
        );
        return EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Couldn\'t load payment gateways',
          message:
              '${friendlyError(error)}\n\nIf this is a new setup, make sure the Cloud Functions are deployed (firebase deploy --only functions).',
          action: TextButton.icon(
            onPressed: () => ref.invalidate(_adminGatewaysProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        );
      },
      data: (gateways) => Column(
        children: [
          for (final g in gateways) ...[
            _GatewayCard(key: ValueKey(g.id), config: g),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _GatewayCard extends ConsumerStatefulWidget {
  const _GatewayCard({super.key, required this.config});

  final GatewayAdminConfig config;

  @override
  ConsumerState<_GatewayCard> createState() => _GatewayCardState();
}

class _GatewayCardState extends ConsumerState<_GatewayCard> {
  late final Map<String, TextEditingController> _controllers = {
    for (final f in widget.config.fields)
      f.key: TextEditingController(text: f.secret ? '' : f.value),
  };
  late final Map<String, String> _choices = {
    for (final f in widget.config.fields)
      if (f.options != null)
        f.key: f.value.isNotEmpty ? f.value : f.options!.first,
  };
  late String _mode = widget.config.mode;
  late bool _enabled = widget.config.enabled;
  final Set<String> _revealed = {};
  bool _saving = false;
  bool _testing = false;

  GatewayAdminConfig get config => widget.config;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Whether the form (saved values + anything typed now) has every
  /// required field — mirrors the server's isComplete() closely enough to
  /// gate the Enable switch; the server re-checks on save.
  bool get _wouldBeComplete {
    for (final f in config.fields.where((f) => f.required)) {
      final typed = f.options != null
          ? _choices[f.key] ?? ''
          : _controllers[f.key]!.text.trim();
      if (typed.isEmpty && !f.hasValue) return false;
    }
    return true;
  }

  Map<String, String> _collectValues() {
    return {
      for (final f in config.fields)
        f.key: f.options != null
            ? _choices[f.key] ?? ''
            : _controllers[f.key]!.text.trim(),
    };
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _save({bool clear = false}) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(paymentsRepositoryProvider)
          .adminSaveGateway(
            id: config.id,
            mode: _mode,
            enabled: clear ? false : _enabled && _wouldBeComplete,
            values: clear ? const {} : _collectValues(),
            clear: clear,
          );
      _snack(
        clear
            ? '${config.displayName}: credentials removed'
            : '${config.displayName} saved',
      );
      ref.invalidate(_adminGatewaysProvider);
    } catch (error, stack) {
      appLogger.e(
        '[payments-admin] Save ${config.id.name} failed',
        error: error,
        stackTrace: stack,
      );
      _snack(friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      final result = await ref
          .read(paymentsRepositoryProvider)
          .adminTestGateway(config.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(
            result.ok ? Icons.check_circle_rounded : Icons.error_rounded,
            color: result.ok
                ? Colors.green
                : Theme.of(context).colorScheme.error,
            size: 40,
          ),
          title: Text(result.ok ? 'Connection OK' : 'Connection failed'),
          content: Text(result.message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      ref.invalidate(_adminGatewaysProvider);
    } catch (error) {
      _snack(friendlyError(error));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${config.displayName} credentials?'),
        content: const Text(
          'Customers will immediately stop seeing this payment method.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) await _save(clear: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = config.enabled
        ? ('Live for customers', Colors.green)
        : config.configured
        ? ('Ready — switched off', theme.colorScheme.tertiary)
        : ('Awaiting credentials', theme.colorScheme.onSurfaceVariant);

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const Border(),
        leading: Icon(config.id.icon),
        title: Text(
          config.displayName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.circle, size: 10, color: status.$2),
            const SizedBox(width: 6),
            Flexible(child: Text(status.$1)),
            if (config.configured) ...[
              const SizedBox(width: 8),
              Text(
                config.mode == 'live' ? '· LIVE' : '· SANDBOX',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(config.description, style: theme.textTheme.bodySmall),
          if (config.signupUrl.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(config.signupUrl)),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open provider dashboard'),
              ),
            ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'sandbox',
                label: Text('Sandbox / Test'),
                icon: Icon(Icons.science_outlined),
              ),
              ButtonSegment(
                value: 'live',
                label: Text('Live'),
                icon: Icon(Icons.bolt_rounded),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
          const SizedBox(height: 16),
          for (final f in config.fields) ...[
            if (f.options != null)
              DropdownButtonFormField<String>(
                initialValue: _choices[f.key],
                decoration: InputDecoration(
                  labelText: f.label + (f.required ? ' *' : ''),
                  helperText: f.help,
                  helperMaxLines: 3,
                ),
                items: [
                  for (final o in f.options!)
                    DropdownMenuItem(value: o, child: Text(o)),
                ],
                onChanged: (v) => setState(() => _choices[f.key] = v!),
              )
            else
              TextField(
                controller: _controllers[f.key],
                obscureText: f.secret && !_revealed.contains(f.key),
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: f.label + (f.required ? ' *' : ''),
                  helperText: f.secret && f.hasValue
                      ? 'Saved (${f.preview}). Leave blank to keep it. ${f.help}'
                      : f.help,
                  helperMaxLines: 3,
                  suffixIcon: f.secret
                      ? IconButton(
                          tooltip: _revealed.contains(f.key) ? 'Hide' : 'Show',
                          icon: Icon(
                            _revealed.contains(f.key)
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                          onPressed: () => setState(
                            () => _revealed.contains(f.key)
                                ? _revealed.remove(f.key)
                                : _revealed.add(f.key),
                          ),
                        )
                      : null,
                ),
              ),
            const SizedBox(height: 12),
          ],
          if (config.integrationUrls.isNotEmpty) ...[
            Text(
              'URLs for the provider dashboard',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            for (final e in config.integrationUrls.entries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.key),
                subtitle: SelectableText(e.value),
                trailing: IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: e.value));
                    _snack('Copied');
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show to customers at checkout'),
            subtitle: Text(
              _wouldBeComplete
                  ? 'Takes effect when you save.'
                  : 'Fill in every required (*) field to enable.',
            ),
            value: _enabled && _wouldBeComplete,
            onChanged: _wouldBeComplete
                ? (v) => setState(() => _enabled = v)
                : null,
          ),
          if (config.lastTestMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    config.lastTestOk == true
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    size: 16,
                    color: config.lastTestOk == true
                        ? Colors.green
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Last test: ${config.lastTestMessage}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(),
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save'),
              ),
              OutlinedButton.icon(
                onPressed: _testing || !config.configured ? null : _test,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check_rounded),
                label: const Text('Test connection'),
              ),
              if (config.configured)
                TextButton.icon(
                  onPressed: _saving ? null : _confirmClear,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove credentials'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BusinessSettingsCard extends ConsumerStatefulWidget {
  const _BusinessSettingsCard();

  @override
  ConsumerState<_BusinessSettingsCard> createState() =>
      _BusinessSettingsCardState();
}

class _BusinessSettingsCardState extends ConsumerState<_BusinessSettingsCard> {
  final _formKey = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  final _appBaseUrl = TextEditingController();
  final _supportPhone = TextEditingController();
  final _supportEmail = TextEditingController();
  final _kraPin = TextEditingController();
  final _vatPercent = TextEditingController();
  final _deliveryFee = TextEditingController();
  final _freeDelivery = TextEditingController();
  final _depositPercent = TextEditingController();
  bool _vatEnabled = false;
  bool _pricesIncludeVat = true;
  bool _allowDeposit = true;
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _businessName,
      _appBaseUrl,
      _supportPhone,
      _supportEmail,
      _kraPin,
      _vatPercent,
      _deliveryFee,
      _freeDelivery,
      _depositPercent,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _seed(BusinessSettings s) {
    if (_seeded) return;
    _seeded = true;
    _businessName.text = s.businessName;
    _appBaseUrl.text = s.appBaseUrl;
    _supportPhone.text = s.supportPhone;
    _supportEmail.text = s.supportEmail;
    _kraPin.text = s.kraPin;
    _vatPercent.text = (s.vatRate * 100).toStringAsFixed(0);
    _deliveryFee.text = s.deliveryFlatFee.toString();
    _freeDelivery.text = s.freeDeliveryThreshold.toString();
    _depositPercent.text = s.depositPercent.toString();
    _vatEnabled = s.vatEnabled;
    _pricesIncludeVat = s.pricesIncludeVat;
    _allowDeposit = s.allowDeposit;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(paymentsRepositoryProvider)
          .saveBusinessSettings(
            BusinessSettings(
              businessName: _businessName.text.trim(),
              appBaseUrl: _appBaseUrl.text.trim().replaceAll(
                RegExp(r'/+$'),
                '',
              ),
              supportPhone: _supportPhone.text.trim(),
              supportEmail: _supportEmail.text.trim(),
              kraPin: _kraPin.text.trim().toUpperCase(),
              vatEnabled: _vatEnabled,
              vatRate: double.parse(_vatPercent.text.trim()) / 100,
              pricesIncludeVat: _pricesIncludeVat,
              deliveryFlatFee: num.parse(_deliveryFee.text.trim()),
              freeDeliveryThreshold: num.parse(_freeDelivery.text.trim()),
              allowDeposit: _allowDeposit,
              depositPercent: num.parse(_depositPercent.text.trim()),
            ),
            uid: uid,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business settings saved'),
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

  String? _number(String? v, {num min = 0, num? max}) {
    final n = num.tryParse((v ?? '').trim());
    if (n == null) return 'Enter a number';
    if (n < min) return 'Must be at least $min';
    if (max != null && n > max) return 'Must be at most $max';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(businessSettingsProvider);
    if (async.hasValue) _seed(async.value!);
    if (!_seeded) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    Widget pair(Widget a, Widget b) => LayoutBuilder(
      builder: (context, c) => c.maxWidth < 560
          ? Column(children: [a, const SizedBox(height: 12), b])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: a),
                const SizedBox(width: 12),
                Expanded(child: b),
              ],
            ),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Business & tax',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              pair(
                TextFormField(
                  controller: _businessName,
                  decoration: const InputDecoration(labelText: 'Business name'),
                  validator: (v) =>
                      (v ?? '').trim().length < 2 ? 'Required' : null,
                ),
                TextFormField(
                  controller: _kraPin,
                  decoration: const InputDecoration(
                    labelText: 'KRA PIN (printed on invoices)',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              pair(
                TextFormField(
                  controller: _supportPhone,
                  decoration: const InputDecoration(labelText: 'Support phone'),
                ),
                TextFormField(
                  controller: _supportEmail,
                  decoration: const InputDecoration(labelText: 'Support email'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _appBaseUrl,
                decoration: const InputDecoration(
                  labelText: 'App web address',
                  helperText:
                      'Where customers return after card/PayPal/Flutterwave checkout.',
                ),
                validator: (v) => (v ?? '').trim().startsWith('https://')
                    ? null
                    : 'Must start with https://',
              ),
              const Divider(height: 32),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Charge VAT'),
                subtitle: const Text(
                  'Turn on once you\'re VAT-registered with KRA.',
                ),
                value: _vatEnabled,
                onChanged: (v) => setState(() => _vatEnabled = v),
              ),
              if (_vatEnabled) ...[
                pair(
                  TextFormField(
                    controller: _vatPercent,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: const InputDecoration(
                      labelText: 'VAT rate (%)',
                    ),
                    validator: (v) => _number(v, max: 100),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Catalog prices include VAT'),
                    value: _pricesIncludeVat,
                    onChanged: (v) => setState(() => _pricesIncludeVat = v),
                  ),
                ),
              ],
              const Divider(height: 32),
              pair(
                TextFormField(
                  controller: _deliveryFee,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(
                    labelText: 'Delivery fee (KES)',
                    helperText: '0 = free delivery',
                  ),
                  validator: (v) => _number(v, max: 10000000),
                ),
                TextFormField(
                  controller: _freeDelivery,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(
                    labelText: 'Free delivery from (KES)',
                    helperText: '0 = never free',
                  ),
                  validator: (v) => _number(v),
                ),
              ),
              const Divider(height: 32),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow paying a deposit'),
                subtitle: const Text(
                  'Customers can pay part upfront and the balance before delivery.',
                ),
                value: _allowDeposit,
                onChanged: (v) => setState(() => _allowDeposit = v),
              ),
              if (_allowDeposit)
                TextFormField(
                  controller: _depositPercent,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(
                    labelText: 'Deposit (% of order total)',
                  ),
                  validator: (v) => _number(v, min: 1, max: 99),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save business settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
