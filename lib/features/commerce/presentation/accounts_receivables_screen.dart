import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/formatting/currency.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../growth/companies.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/domain/order_status.dart';
import '../../payments/presentation/widgets/record_payment_dialog.dart';
import '../application/commerce_providers.dart';
import '../data/commerce_repository.dart';

/// Admin/CEO: money owed, business customers' terms, promo codes and the
/// accountant's export — the back office for items 21–27.
class AccountsReceivablesScreen extends StatelessWidget {
  const AccountsReceivablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 5,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.request_page_outlined), text: 'Receivables'),
              Tab(
                icon: Icon(Icons.business_outlined),
                text: 'Business accounts',
              ),
              Tab(
                icon: Icon(Icons.apartment_rounded),
                text: 'Companies & uniforms',
              ),
              Tab(icon: Icon(Icons.local_offer_outlined), text: 'Promo codes'),
              Tab(icon: Icon(Icons.file_download_outlined), text: 'Export'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ReceivablesTab(),
                _AccountsTab(),
                CompaniesTab(),
                _CouponsTab(),
                _ExportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- Receivables

class _Debtor {
  _Debtor(this.customerId);

  final String customerId;
  String name = '';
  String phone = '';
  final List<OrderModel> orders = [];
  num current = 0;
  num d30 = 0;
  num d60 = 0;
  num d90 = 0;

  num get total => current + d30 + d60 + d90;
}

class _ReceivablesTab extends ConsumerWidget {
  const _ReceivablesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(allOrdersProvider);
    final accounts = ref.watch(allAccountsProvider).valueOrNull ?? const {};
    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn\'t load orders',
        message: friendlyError(e),
      ),
      data: (orders) {
        final now = DateTime.now();
        final debtors = <String, _Debtor>{};
        for (final o in orders) {
          if (o.status == OrderStatus.cancelled || o.balanceDue <= 0) continue;
          final d = debtors.putIfAbsent(
            o.customerId,
            () => _Debtor(o.customerId),
          );
          d.name = accounts[o.customerId]?.companyName.isNotEmpty == true
              ? accounts[o.customerId]!.companyName
              : (o.customerCompany ?? o.contactName);
          d.phone = o.contactPhone;
          d.orders.add(o);
          final due = o.dueDate ?? o.createdAt;
          final late = now.difference(due).inDays;
          if (late <= 0) {
            d.current += o.balanceDue;
          } else if (late <= 30) {
            d.d30 += o.balanceDue;
          } else if (late <= 60) {
            d.d60 += o.balanceDue;
          } else {
            d.d90 += o.balanceDue;
          }
        }
        final list = debtors.values.toList()
          ..sort((a, b) => b.total.compareTo(a.total));
        final totals = list.fold<List<num>>(
          [0, 0, 0, 0],
          (t, d) => [
            t[0] + d.current,
            t[1] + d.d30,
            t[2] + d.d60,
            t[3] + d.d90,
          ],
        );
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Nothing outstanding',
            message: 'Every order is fully paid.',
          );
        }
        Widget bucket(String label, num v, {Color? color}) => Expanded(
          child: Card(
            margin: const EdgeInsets.all(4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    child: Text(
                      currencyFormat.format(v),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                bucket('Not yet due', totals[0]),
                bucket('1–30 days late', totals[1], color: Colors.orange),
                bucket('31–60 days', totals[2], color: Colors.deepOrange),
                bucket('60+ days', totals[3], color: theme.colorScheme.error),
              ],
            ),
            const SizedBox(height: 8),
            for (final d in list)
              Card(
                child: ExpansionTile(
                  title: Text(d.name),
                  subtitle: Text(
                    '${currencyFormat.format(d.total)} owed · ${d.orders.length} invoice(s)'
                    '${d.d30 + d.d60 + d.d90 > 0 ? ' · ${currencyFormat.format(d.d30 + d.d60 + d.d90)} overdue' : ''}',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    for (final o in d.orders)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${o.invoiceNumber.isEmpty ? o.displayNumber : o.invoiceNumber} · ${currencyFormat.format(o.balanceDue)} due',
                        ),
                        subtitle: Text(
                          o.dueDate == null
                              ? 'Ordered ${DateFormat('d MMM y').format(o.createdAt)}'
                              : '${o.overdue ? 'Overdue' : 'Due'} ${DateFormat('d MMM y').format(o.dueDate!)}',
                        ),
                        trailing: TextButton(
                          onPressed: () => showRecordPaymentDialog(context, o),
                          child: const Text('Record payment'),
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => openDocument(
                            context,
                            ref,
                            DocumentKind.statement,
                            d.customerId,
                          ),
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('Statement PDF'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _whatsappReminder(ref, d),
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('WhatsApp reminder'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// Opens WhatsApp with a polite, pre-filled reminder (staff review and
  /// send it themselves).
  Future<void> _whatsappReminder(WidgetRef ref, _Debtor d) async {
    final digits = d.phone.replaceAll(RegExp(r'[^\d]'), '');
    final intl = digits.startsWith('0') ? '254${digits.substring(1)}' : digits;
    final lines = d.orders
        .map(
          (o) =>
              '• ${o.invoiceNumber.isEmpty ? o.displayNumber : o.invoiceNumber}: ${currencyFormat.format(o.balanceDue)}',
        )
        .join('\n');
    final text =
        'Hello ${d.name}, this is a friendly reminder from BrightBrush Creations. '
        'The following balance is outstanding:\n$lines\n'
        'Total: ${currencyFormat.format(d.total)}. You can pay from your order page in the app. Thank you!';
    await launchUrl(
      Uri.parse('https://wa.me/$intl?text=${Uri.encodeComponent(text)}'),
      mode: LaunchMode.externalApplication,
    );
  }
}

// ------------------------------------------------------- Business accounts

class _AccountsTab extends ConsumerStatefulWidget {
  const _AccountsTab();

  @override
  ConsumerState<_AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends ConsumerState<_AccountsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(allUserProfilesProvider);
    final accounts = ref.watch(allAccountsProvider).valueOrNull ?? const {};
    return users.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn\'t load customers',
        message: friendlyError(e),
      ),
      data: (profiles) {
        final customers =
            profiles.where((p) => p.role == AppRole.user).where((p) {
              final q = _query.toLowerCase();
              return q.isEmpty ||
                  p.displayName.toLowerCase().contains(q) ||
                  p.email.toLowerCase().contains(q) ||
                  (accounts[p.uid]?.companyName.toLowerCase().contains(q) ??
                      false);
            }).toList()..sort((a, b) {
              final ab = accounts[a.uid]?.isBusiness == true ? 0 : 1;
              final bb = accounts[b.uid]?.isBusiness == true ? 0 : 1;
              return ab != bb
                  ? ab.compareTo(bb)
                  : a.displayName.compareTo(b.displayName);
            });
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search customers or companies',
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
            const SizedBox(height: 8),
            for (final p in customers)
              Card(
                child: ListTile(
                  leading: Icon(
                    accounts[p.uid]?.isBusiness == true
                        ? Icons.business_rounded
                        : Icons.person_outline,
                  ),
                  title: Text(
                    accounts[p.uid]?.companyName.isNotEmpty == true
                        ? '${accounts[p.uid]!.companyName} · ${p.displayName}'
                        : p.displayName,
                  ),
                  subtitle: Text(
                    [
                      p.email,
                      if ((accounts[p.uid]?.discountPercent ?? 0) > 0)
                        '${accounts[p.uid]!.discountPercent}% discount',
                      if (accounts[p.uid]?.creditEnabled == true)
                        'credit ${accounts[p.uid]!.paymentTermsDays}d${accounts[p.uid]!.creditLimit > 0 ? ', limit ${currencyFormat.format(accounts[p.uid]!.creditLimit)}' : ''}',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => _AccountDialog(
                      account: accounts[p.uid] ?? CustomerAccount(uid: p.uid),
                      customerName: p.displayName,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AccountDialog extends ConsumerStatefulWidget {
  const _AccountDialog({required this.account, required this.customerName});

  final CustomerAccount account;
  final String customerName;

  @override
  ConsumerState<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends ConsumerState<_AccountDialog> {
  late final _company = TextEditingController(text: widget.account.companyName);
  late final _pin = TextEditingController(text: widget.account.kraPin);
  late final _discount = TextEditingController(
    text: '${widget.account.discountPercent}',
  );
  late final _limit = TextEditingController(
    text: '${widget.account.creditLimit}',
  );
  late final _terms = TextEditingController(
    text: '${widget.account.paymentTermsDays}',
  );
  late final _notes = TextEditingController(text: widget.account.notes);
  late bool _credit = widget.account.creditEnabled;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_company, _pin, _discount, _limit, _terms, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(commerceRepositoryProvider)
          .saveAccount(
            CustomerAccount(
              uid: widget.account.uid,
              companyName: _company.text.trim(),
              kraPin: _pin.text.trim().toUpperCase(),
              discountPercent: (num.tryParse(_discount.text.trim()) ?? 0).clamp(
                0,
                100,
              ),
              creditEnabled: _credit,
              creditLimit: num.tryParse(_limit.text.trim()) ?? 0,
              paymentTermsDays: (int.tryParse(_terms.text.trim()) ?? 30).clamp(
                0,
                365,
              ),
              notes: _notes.text.trim(),
            ),
            adminUid: uid,
          );
      if (mounted) Navigator.pop(context);
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
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    return AlertDialog(
      title: Text('Account · ${widget.customerName}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _company,
                decoration: const InputDecoration(
                  labelText: 'Company name (on invoices)',
                ),
              ),
              TextField(
                controller: _pin,
                decoration: const InputDecoration(
                  labelText: 'Company KRA PIN (for eTIMS)',
                ),
              ),
              TextField(
                controller: _discount,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                decoration: const InputDecoration(
                  labelText: 'Standing discount (%)',
                  helperText: 'Applied automatically at checkout',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Credit terms (pay on account)'),
                value: _credit,
                onChanged: (v) => setState(() => _credit = v),
              ),
              if (_credit) ...[
                TextField(
                  controller: _terms,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Payment terms (days)',
                    helperText: 'e.g. 30 for net-30',
                  ),
                ),
                TextField(
                  controller: _limit,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Credit limit (KES)',
                    helperText: '0 = no limit',
                  ),
                ),
              ],
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Internal notes'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ Promo codes

class _CouponsTab extends ConsumerWidget {
  const _CouponsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(couponsProvider);
    final date = DateFormat('d MMM y');
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _CouponDialog(),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New code'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Couldn\'t load codes',
          message: friendlyError(e),
        ),
        data: (coupons) => coupons.isEmpty
            ? const EmptyState(
                icon: Icons.local_offer_outlined,
                title: 'No promo codes yet',
                message:
                    'Create codes for campaigns — e.g. VALENTINE10 for 10% off.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  for (final c in coupons)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.local_offer_rounded,
                          color: c.active ? Colors.green : null,
                        ),
                        title: Text(c.code),
                        subtitle: Text(
                          [
                            c.type == 'percent'
                                ? '${c.value}% off'
                                : '${currencyFormat.format(c.value)} off',
                            if (c.minSubtotal > 0)
                              'min ${currencyFormat.format(c.minSubtotal)}',
                            'used ${c.usedCount}${c.usageLimit > 0 ? '/${c.usageLimit}' : ''}',
                            if (c.validTo != null)
                              'ends ${date.format(c.validTo!)}',
                            if (!c.active) 'paused',
                          ].join(' · '),
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => ref
                              .read(commerceRepositoryProvider)
                              .deleteCoupon(c.code),
                        ),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => _CouponDialog(existing: c),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _CouponDialog extends ConsumerStatefulWidget {
  const _CouponDialog({this.existing});

  final Coupon? existing;

  @override
  ConsumerState<_CouponDialog> createState() => _CouponDialogState();
}

class _CouponDialogState extends ConsumerState<_CouponDialog> {
  late final _code = TextEditingController(text: widget.existing?.code ?? '');
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _value = TextEditingController(
    text: '${widget.existing?.value ?? 10}',
  );
  late final _min = TextEditingController(
    text: '${widget.existing?.minSubtotal ?? 0}',
  );
  late final _max = TextEditingController(
    text: '${widget.existing?.maxDiscount ?? 0}',
  );
  late final _limit = TextEditingController(
    text: '${widget.existing?.usageLimit ?? 0}',
  );
  late final _perCustomer = TextEditingController(
    text: '${widget.existing?.perCustomerLimit ?? 1}',
  );
  late String _type = widget.existing?.type ?? 'percent';
  late bool _active = widget.existing?.active ?? true;
  late DateTime? _validTo = widget.existing?.validTo;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _code,
      _description,
      _value,
      _min,
      _max,
      _limit,
      _perCustomer,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final code = _code.text.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9_-]'),
      '',
    );
    if (code.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Codes need at least 3 letters/numbers.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(commerceRepositoryProvider)
          .saveCoupon(
            Coupon(
              code: code,
              description: _description.text.trim(),
              type: _type,
              value: num.tryParse(_value.text.trim()) ?? 0,
              minSubtotal: num.tryParse(_min.text.trim()) ?? 0,
              maxDiscount: num.tryParse(_max.text.trim()) ?? 0,
              validTo: _validTo,
              usageLimit: int.tryParse(_limit.text.trim()) ?? 0,
              perCustomerLimit: int.tryParse(_perCustomer.text.trim()) ?? 0,
              active: _active,
            ),
            isNew: widget.existing == null,
          );
      if (mounted) Navigator.pop(context);
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
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'New promo code'
            : 'Edit ${widget.existing!.code}',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _code,
                enabled: widget.existing == null,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Code',
                  hintText: 'e.g. VALENTINE10',
                ),
              ),
              TextField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Description (shown when applied)',
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'percent', label: Text('% off')),
                  ButtonSegment(value: 'fixed', label: Text('KES off')),
                ],
                selected: {_type},
                onSelectionChanged: (v) => setState(() => _type = v.first),
              ),
              TextField(
                controller: _value,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                decoration: InputDecoration(
                  labelText: _type == 'percent'
                      ? 'Percent off'
                      : 'Amount off (KES)',
                ),
              ),
              TextField(
                controller: _min,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                decoration: const InputDecoration(
                  labelText: 'Minimum spend (KES)',
                ),
              ),
              if (_type == 'percent')
                TextField(
                  controller: _max,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(
                    labelText: 'Maximum discount (KES, 0 = no cap)',
                  ),
                ),
              TextField(
                controller: _limit,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                decoration: const InputDecoration(
                  labelText: 'Total uses allowed (0 = unlimited)',
                ),
              ),
              TextField(
                controller: _perCustomer,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                decoration: const InputDecoration(
                  labelText: 'Uses per customer (0 = unlimited)',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _validTo == null
                      ? 'No end date'
                      : 'Ends ${DateFormat('d MMM y').format(_validTo!)}',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      initialDate:
                          _validTo ??
                          DateTime.now().add(const Duration(days: 14)),
                    );
                    if (picked != null) {
                      setState(
                        () => _validTo = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          23,
                          59,
                          59,
                        ),
                      );
                    }
                  },
                  child: const Text('Set end date'),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- Export

class _ExportTab extends ConsumerStatefulWidget {
  const _ExportTab();

  @override
  ConsumerState<_ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends ConsumerState<_ExportTab> {
  late DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );
  Map<String, dynamic>? _result;
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(commerceRepositoryProvider)
          .exportAccounting(_range.start, _range.end);
      setState(() => _result = r);
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('d MMM y');
    final r = _result;
    final summary = r == null
        ? null
        : Map<String, dynamic>.from(r['summary'] as Map);
    final stamp =
        '${DateFormat('yyyyMMdd').format(_range.start)}-${DateFormat('yyyyMMdd').format(_range.end)}';
    Widget row(String label, Object? v, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
            ),
          ),
          Text(
            currencyFormat.format(v as num? ?? 0),
            style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
          ),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Accounting export',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'CSV files for your accountant or for import into Xero / QuickBooks (sales use the Xero sales-invoice layout; account code 200).',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                  initialDateRange: _range,
                );
                if (picked != null) setState(() => _range = picked);
              },
              icon: const Icon(Icons.date_range_rounded),
              label: Text(
                '${fmt.format(_range.start)} – ${fmt.format(_range.end)}',
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _run,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Generate'),
            ),
          ],
        ),
        if (summary != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profit & loss (cash basis)',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  row(
                    'Invoiced (${summary['orderCount']} orders)',
                    summary['invoiced'],
                  ),
                  row('VAT on invoices', summary['vatOnInvoices']),
                  const Divider(),
                  row('Cash collected', summary['collected']),
                  row('Refunds', -(summary['refunded'] as num? ?? 0)),
                  row('Net collected', summary['netCollected'], bold: true),
                  for (final e in Map<String, dynamic>.from(
                    summary['expensesByCategory'] as Map,
                  ).entries)
                    row('Expenses: ${e.key}', -(e.value as num)),
                  const Divider(),
                  row('Net profit', summary['netProfitCashBasis'], bold: true),
                ],
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, key) in [
                ('Sales invoices', 'salesCsv'),
                ('Payments', 'paymentsCsv'),
                ('Refunds', 'refundsCsv'),
                ('Expenses', 'expensesCsv'),
              ])
                OutlinedButton.icon(
                  onPressed: () => saveCsv(
                    context,
                    '${label.toLowerCase().replaceAll(' ', '-')}-$stamp.csv',
                    r![key] as String,
                  ),
                  icon: const Icon(Icons.table_view_outlined),
                  label: Text('$label CSV'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
