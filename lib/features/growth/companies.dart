import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/app_role.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/formatting/currency.dart';
import '../../core/logging/stream_error_logger.dart';
import '../../shared/widgets/empty_state.dart';
import '../customization/domain/customization_pricing.dart';
import '../orders/application/orders_providers.dart';

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.kraPin,
    required this.discountPercent,
    required this.creditEnabled,
    required this.creditLimit,
    required this.paymentTermsDays,
    required this.memberIds,
    required this.notes,
  });

  final String id;
  final String name;
  final String kraPin;
  final num discountPercent;
  final bool creditEnabled;
  final num creditLimit;
  final int paymentTermsDays;
  final List<String> memberIds;
  final String notes;

  factory Company.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Company(
      id: doc.id,
      name: d['name'] as String? ?? '',
      kraPin: d['kraPin'] as String? ?? '',
      discountPercent: d['discountPercent'] as num? ?? 0,
      creditEnabled: d['creditEnabled'] as bool? ?? false,
      creditLimit: d['creditLimit'] as num? ?? 0,
      paymentTermsDays: (d['paymentTermsDays'] as num?)?.toInt() ?? 30,
      memberIds: (d['memberIds'] as List?)?.cast<String>() ?? const [],
      notes: d['notes'] as String? ?? '',
    );
  }
}

/// A pre-approved branded item in a uniform program: the item plus its
/// decorations (artwork, placements, colours); buyers only pick sizes.
class ProgramItem {
  const ProgramItem({required this.label, required this.config});

  final String label;
  final CustomLineConfig config;

  factory ProgramItem.fromMap(Map<String, dynamic> d) => ProgramItem(
    label: d['label'] as String? ?? '',
    config: CustomLineConfig.fromMap(
      Map<String, dynamic>.from((d['config'] as Map?) ?? const {}),
    ),
  );

  Map<String, dynamic> toMap() => {
    'label': label,
    'config': config.copyWith(sizeQuantities: const {}).toCartMap(),
  };
}

class UniformProgram {
  const UniformProgram({
    required this.id,
    required this.companyId,
    required this.name,
    required this.description,
    required this.active,
    required this.items,
  });

  final String id;
  final String companyId;
  final String name;
  final String description;
  final bool active;
  final List<ProgramItem> items;

  factory UniformProgram.fromFirestore(
    String companyId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return UniformProgram(
      id: doc.id,
      companyId: companyId,
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      active: d['active'] as bool? ?? false,
      items: [
        for (final i in (d['items'] as List? ?? const []))
          ProgramItem.fromMap(Map<String, dynamic>.from(i as Map)),
      ],
    );
  }
}

/// The signed-in buyer's company (if they belong to one).
final myCompanyProvider = StreamProvider<Company?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('Companies')
      .where('memberIds', arrayContains: uid)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : Company.fromFirestore(s.docs.first))
      .handleError((Object _) => null);
});

final companyProgramsProvider = StreamProvider.autoDispose
    .family<List<UniformProgram>, String>(
      (ref, companyId) => ref
          .watch(firestoreProvider)
          .collection('Companies')
          .doc(companyId)
          .collection('Programs')
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => UniformProgram.fromFirestore(companyId, d))
                .toList(),
          )
          .transform(logStreamErrors('[programs] $companyId failed')),
    );

final allCompaniesProvider = StreamProvider<List<Company>>((ref) {
  ref.watch(authStateProvider);
  return ref
      .watch(firestoreProvider)
      .collection('Companies')
      .snapshots()
      .map(
        (s) =>
            s.docs.map(Company.fromFirestore).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      )
      .transform(logStreamErrors('[companies] stream failed'));
});

/// Customer home card: the company's active uniform program(s).
class MyUniformProgramsCard extends ConsumerWidget {
  const MyUniformProgramsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(myCompanyProvider).valueOrNull;
    if (company == null) return const SizedBox.shrink();
    final programs =
        (ref.watch(companyProgramsProvider(company.id)).valueOrNull ?? const [])
            .where((p) => p.active && p.items.isNotEmpty)
            .toList();
    if (programs.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${company.name} uniforms',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Approved branded items for your team — just choose sizes.',
              style: theme.textTheme.bodySmall,
            ),
            for (final p in programs) ...[
              const SizedBox(height: 8),
              Text(p.name, style: theme.textTheme.labelLarge),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, item) in p.items.indexed)
                    ActionChip(
                      avatar: const Icon(Icons.checkroom_rounded, size: 18),
                      label: Text(item.label),
                      onPressed: () => context.push(
                        '/customer/catalog/${item.config.itemId}/customize?program=${p.companyId}/${p.id}/$i',
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Resolves "companyId/programId/index" into the program item's config.
final programItemProvider = FutureProvider.autoDispose
    .family<CustomLineConfig?, String>((ref, key) async {
      final parts = key.split('/');
      if (parts.length != 3) return null;
      final doc = await ref
          .read(firestoreProvider)
          .collection('Companies')
          .doc(parts[0])
          .collection('Programs')
          .doc(parts[1])
          .get();
      if (!doc.exists) return null;
      final program = UniformProgram.fromFirestore(parts[0], doc);
      final i = int.tryParse(parts[2]) ?? -1;
      return i >= 0 && i < program.items.length
          ? program.items[i].config
          : null;
    });

// ------------------------------------------------------------ Admin tab

class CompaniesTab extends ConsumerWidget {
  const CompaniesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companies = ref.watch(allCompaniesProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _CompanyDialog(),
        ),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('New company'),
      ),
      body: companies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Couldn\'t load companies',
          message: friendlyError(e),
        ),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.business_outlined,
                title: 'No companies yet',
                message:
                    'Group buyers from the same organisation: shared discount, credit and uniform programs.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [for (final c in list) _CompanyCard(company: c)],
              ),
      ),
    );
  }
}

class _CompanyCard extends ConsumerWidget {
  const _CompanyCard({required this.company});

  final Company company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programs =
        ref.watch(companyProgramsProvider(company.id)).valueOrNull ?? const [];
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.business_rounded),
        title: Text(company.name),
        subtitle: Text(
          [
            '${company.memberIds.length} buyer(s)',
            if (company.discountPercent > 0) '${company.discountPercent}% off',
            if (company.creditEnabled)
              '${company.paymentTermsDays}-day terms${company.creditLimit > 0 ? ', limit ${currencyFormat.format(company.creditLimit)}' : ''}',
          ].join(' · '),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _CompanyDialog(existing: company),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit company & buyers'),
            ),
          ),
          for (final p in programs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                p.active ? Icons.checkroom_rounded : Icons.pause_circle_outline,
              ),
              title: Text(p.name),
              subtitle: Text(p.items.map((i) => i.label).join(', ')),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => _ProgramDialog(company: company, existing: p),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _ProgramDialog(company: company),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New uniform program'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyDialog extends ConsumerStatefulWidget {
  const _CompanyDialog({this.existing});

  final Company? existing;

  @override
  ConsumerState<_CompanyDialog> createState() => _CompanyDialogState();
}

class _CompanyDialogState extends ConsumerState<_CompanyDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _pin = TextEditingController(text: widget.existing?.kraPin ?? '');
  late final _discount = TextEditingController(
    text: '${widget.existing?.discountPercent ?? 0}',
  );
  late final _limit = TextEditingController(
    text: '${widget.existing?.creditLimit ?? 0}',
  );
  late final _terms = TextEditingController(
    text: '${widget.existing?.paymentTermsDays ?? 30}',
  );
  late bool _credit = widget.existing?.creditEnabled ?? false;
  late final Set<String> _members = {...?widget.existing?.memberIds};
  String _query = '';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _pin, _discount, _limit, _terms]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) return;
    setState(() => _saving = true);
    try {
      final col = ref.read(firestoreProvider).collection('Companies');
      final data = {
        'name': _name.text.trim(),
        'kraPin': _pin.text.trim().toUpperCase(),
        'discountPercent': (num.tryParse(_discount.text) ?? 0).clamp(0, 100),
        'creditEnabled': _credit,
        'creditLimit': num.tryParse(_limit.text) ?? 0,
        'paymentTermsDays': (int.tryParse(_terms.text) ?? 30).clamp(0, 365),
        'memberIds': _members.toList(),
        'notes': widget.existing?.notes ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': ref.read(currentUidProvider),
      };
      if (widget.existing == null) {
        await col.add(data);
      } else {
        await col.doc(widget.existing!.id).set(data);
      }
      if (mounted) Navigator.pop(context);
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
    final users = (ref.watch(allUserProfilesProvider).valueOrNull ?? const [])
        .where((u) => u.role == AppRole.user)
        .toList();
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    final shown = users
        .where((u) {
          final q = _query.toLowerCase();
          return q.isEmpty ||
              u.displayName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              _members.contains(u.uid);
        })
        .take(40);
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'New company'
            : 'Edit ${widget.existing!.name}',
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Company name'),
              ),
              TextField(
                controller: _pin,
                decoration: const InputDecoration(
                  labelText: 'KRA PIN (for invoices / eTIMS)',
                ),
              ),
              TextField(
                controller: _discount,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                decoration: const InputDecoration(
                  labelText: 'Discount for all buyers (%)',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Credit terms'),
                value: _credit,
                onChanged: (v) => setState(() => _credit = v),
              ),
              if (_credit) ...[
                TextField(
                  controller: _terms,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Payment terms (days)',
                  ),
                ),
                TextField(
                  controller: _limit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Company credit limit (KES, 0 = none)',
                  ),
                ),
              ],
              const Divider(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Buyers (${_members.length})',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Find customers by name or email',
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
              for (final u in shown)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _members.contains(u.uid),
                  title: Text(u.displayName),
                  subtitle: Text(u.email),
                  onChanged: (v) => setState(
                    () => v == true
                        ? _members.add(u.uid)
                        : _members.remove(u.uid),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () async {
              await ref
                  .read(firestoreProvider)
                  .collection('Companies')
                  .doc(widget.existing!.id)
                  .delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
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

/// Build a uniform program from customised lines the company already
/// ordered (artwork, placements and colours carry over; buyers pick sizes).
class _ProgramDialog extends ConsumerStatefulWidget {
  const _ProgramDialog({required this.company, this.existing});

  final Company company;
  final UniformProgram? existing;

  @override
  ConsumerState<_ProgramDialog> createState() => _ProgramDialogState();
}

class _ProgramDialogState extends ConsumerState<_ProgramDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late bool _active = widget.existing?.active ?? true;
  late final List<ProgramItem> _items = [...?widget.existing?.items];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) return;
    setState(() => _saving = true);
    try {
      final col = ref
          .read(firestoreProvider)
          .collection('Companies')
          .doc(widget.company.id)
          .collection('Programs');
      final data = {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'active': _active,
        'items': [for (final i in _items) i.toMap()],
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': ref.read(currentUidProvider),
      };
      if (widget.existing == null) {
        await col.add(data);
      } else {
        await col.doc(widget.existing!.id).set(data);
      }
      if (mounted) Navigator.pop(context);
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
    final orders = (ref.watch(allOrdersProvider).valueOrNull ?? const [])
        .where((o) => widget.company.memberIds.contains(o.customerId))
        .toList();
    final candidates = [
      for (final o in orders)
        for (final line in o.items)
          if (line.customization != null)
            (
              order: o.displayNumber,
              name: line.name,
              config: line.customization!,
            ),
    ];
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'New uniform program' : 'Edit program',
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Program name',
                  hintText: 'e.g. 2027 staff uniforms',
                ),
              ),
              TextField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Notes for buyers',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              Text('Items', style: Theme.of(context).textTheme.labelLarge),
              for (final (i, item) in _items.indexed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.label),
                  subtitle: Text(
                    '${item.config.colour ?? ''} · ${item.config.decorations.length} decoration(s)',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _items.removeAt(i)),
                  ),
                ),
              if (candidates.isEmpty)
                const Text(
                  'Items come from customised orders this company has placed. Once a buyer orders a branded item, it can be added here.',
                )
              else
                PopupMenuButton<int>(
                  onSelected: (i) => setState(
                    () => _items.add(
                      ProgramItem(
                        label: candidates[i].name,
                        config: candidates[i].config,
                      ),
                    ),
                  ),
                  itemBuilder: (_) => [
                    for (final (i, c) in candidates.indexed)
                      PopupMenuItem(
                        value: i,
                        child: Text('${c.name} (from ${c.order})'),
                      ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded),
                        SizedBox(width: 6),
                        Text('Add from a past order'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () async {
              await ref
                  .read(firestoreProvider)
                  .collection('Companies')
                  .doc(widget.company.id)
                  .collection('Programs')
                  .doc(widget.existing!.id)
                  .delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
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
