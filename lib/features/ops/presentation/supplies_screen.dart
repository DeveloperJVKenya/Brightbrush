import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/formatting/currency.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../commerce/application/commerce_providers.dart';
import '../../commerce/data/commerce_repository.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/domain/inventory_material.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../application/ops_providers.dart';
import '../data/ops_repository.dart';

/// Stock, purchase orders and the stock ledger in one place.
class SuppliesScreen extends StatelessWidget {
  const SuppliesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Stock'),
              Tab(
                icon: Icon(Icons.local_shipping_outlined),
                text: 'Purchase orders',
              ),
              Tab(icon: Icon(Icons.swap_vert_rounded), text: 'Movements'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                InventoryScreen(),
                _PurchaseOrdersTab(),
                _MovementsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _poStatusLabel = {
  'draft': 'Draft',
  'sent': 'Sent',
  'received': 'Received',
  'cancelled': 'Cancelled',
};

class _PurchaseOrdersTab extends ConsumerWidget {
  const _PurchaseOrdersTab();

  Future<void> _suggest(BuildContext context, WidgetRef ref) async {
    final materials =
        ref.read(allInventoryMaterialsProvider).valueOrNull ?? const [];
    final low = materials.where((m) => m.isLowStock).toList();
    if (low.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing is below its reorder point.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // One draft per supplier.
    final bySupplier = <String, List<InventoryMaterial>>{};
    for (final m in low) {
      bySupplier
          .putIfAbsent(
            m.supplierName.isEmpty ? 'Unknown supplier' : m.supplierName,
            () => [],
          )
          .add(m);
    }
    for (final entry in bySupplier.entries) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _PoDialog(
          supplierName: entry.key,
          supplierContact: entry.value.first.supplierContact,
          initial: [
            for (final m in entry.value)
              PurchaseOrderLine(
                materialId: m.id,
                name: m.name,
                unit: m.unit,
                // Order back up to twice the reorder point.
                quantity: (m.reorderPoint * 2 - m.quantityOnHand).clamp(
                  1,
                  1000000,
                ),
                unitCost: 0,
              ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(purchaseOrdersProvider);
    final isAdmin =
        ref.watch(resolvedRoleProvider).valueOrNull == AppRole.admin ||
        ref.watch(resolvedRoleProvider).valueOrNull == AppRole.developer;
    final date = DateFormat('d MMM y');
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _PoDialog(),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New PO'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Couldn\'t load purchase orders',
          message: friendlyError(e),
        ),
        data: (pos) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _suggest(context, ref),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Suggest from low stock'),
              ),
            ),
            if (pos.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No purchase orders',
                message:
                    'Raise POs to suppliers; receiving one adds the stock automatically.',
              ),
            for (final po in pos)
              Card(
                child: ExpansionTile(
                  title: Text('${po.poNumber} · ${po.supplierName}'),
                  subtitle: Text(
                    '${_poStatusLabel[po.status] ?? po.status} · ${currencyFormat.format(po.total)} · ${date.format(po.createdAt)}'
                    '${po.expectedDate != null ? ' · needed ${date.format(po.expectedDate!)}' : ''}',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    for (final l in po.lines)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${l.quantity} ${l.unit} ${l.name}'),
                        trailing: Text(
                          currencyFormat.format(l.quantity * l.unitCost),
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => openDocument(
                            context,
                            ref,
                            DocumentKind.purchaseOrder,
                            po.id,
                          ),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('PO PDF'),
                        ),
                        if (po.status == 'draft')
                          OutlinedButton(
                            onPressed: () => ref
                                .read(opsRepositoryProvider)
                                .setPurchaseOrderStatus(
                                  po.id,
                                  'sent',
                                  uid: ref.read(currentUidProvider)!,
                                ),
                            child: const Text('Mark sent'),
                          ),
                        if (po.status == 'draft' || po.status == 'sent') ...[
                          FilledButton.icon(
                            onPressed: () =>
                                _receive(context, ref, po, isAdmin),
                            icon: const Icon(Icons.move_to_inbox_rounded),
                            label: const Text('Receive stock'),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(opsRepositoryProvider)
                                .setPurchaseOrderStatus(
                                  po.id,
                                  'cancelled',
                                  uid: ref.read(currentUidProvider)!,
                                ),
                            child: const Text('Cancel PO'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _receive(
    BuildContext context,
    WidgetRef ref,
    PurchaseOrder po,
    bool isAdmin,
  ) async {
    var logExpense = isAdmin;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Receive ${po.poNumber}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Adds every line to stock.'),
              if (isAdmin)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Book ${currencyFormat.format(po.total)} as a materials expense',
                  ),
                  value: logExpense,
                  onChanged: (v) => setState(() => logExpense = v ?? false),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Receive'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(opsRepositoryProvider)
          .receivePurchaseOrder(po.id, logExpense: logExpense);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(error)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _PoDialog extends ConsumerStatefulWidget {
  const _PoDialog({
    this.supplierName,
    this.supplierContact,
    this.initial = const [],
  });

  final String? supplierName;
  final String? supplierContact;
  final List<PurchaseOrderLine> initial;

  @override
  ConsumerState<_PoDialog> createState() => _PoDialogState();
}

class _PoDialogState extends ConsumerState<_PoDialog> {
  late final _supplier = TextEditingController(text: widget.supplierName ?? '');
  late final _contact = TextEditingController(
    text: widget.supplierContact ?? '',
  );
  final _notes = TextEditingController();
  late final List<PurchaseOrderLine> _lines = [...widget.initial];
  DateTime? _needed;
  bool _saving = false;

  @override
  void dispose() {
    _supplier.dispose();
    _contact.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addLine(List<InventoryMaterial> materials) async {
    InventoryMaterial? picked = materials.firstOrNull;
    final qty = TextEditingController(text: '1');
    final cost = TextEditingController(text: '0');
    final line = await showDialog<PurchaseOrderLine>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add material'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<InventoryMaterial>(
                initialValue: picked,
                isExpanded: true,
                items: [
                  for (final m in materials)
                    DropdownMenuItem(
                      value: m,
                      child: Text('${m.name} (${m.quantityOnHand} ${m.unit})'),
                    ),
                ],
                onChanged: (v) => setState(() => picked = v),
              ),
              TextField(
                controller: qty,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              TextField(
                controller: cost,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(labelText: 'Unit cost (KES)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: picked == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      PurchaseOrderLine(
                        materialId: picked!.id,
                        name: picked!.name,
                        unit: picked!.unit,
                        quantity: int.tryParse(qty.text) ?? 1,
                        unitCost: num.tryParse(cost.text) ?? 0,
                      ),
                    ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (line != null) setState(() => _lines.add(line));
  }

  Future<void> _save() async {
    if (_supplier.text.trim().length < 2 || _lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a supplier and at least one line.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final number = await ref
          .read(opsRepositoryProvider)
          .createPurchaseOrder(
            supplierName: _supplier.text.trim(),
            supplierContact: _contact.text.trim(),
            lines: _lines,
            expectedDate: _needed,
            notes: _notes.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$number created'),
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
    final materials =
        ref.watch(allInventoryMaterialsProvider).valueOrNull ?? const [];
    final total = _lines.fold<num>(0, (s, l) => s + l.quantity * l.unitCost);
    return AlertDialog(
      title: const Text('Purchase order'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _supplier,
                decoration: const InputDecoration(labelText: 'Supplier'),
              ),
              TextField(
                controller: _contact,
                decoration: const InputDecoration(
                  labelText: 'Supplier phone / email',
                ),
              ),
              for (final (i, l) in _lines.indexed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${l.quantity} ${l.unit} ${l.name}'),
                  subtitle: Text('${currencyFormat.format(l.unitCost)} each'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _lines.removeAt(i)),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: materials.isEmpty
                      ? null
                      : () => _addLine(materials),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add material'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _needed == null
                      ? 'No needed-by date'
                      : 'Needed by ${DateFormat('d MMM y').format(_needed!)}',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 180)),
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                    );
                    if (d != null) setState(() => _needed = d);
                  },
                  child: const Text('Set date'),
                ),
              ),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes to supplier',
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total ${currencyFormat.format(total)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
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
          child: const Text('Create PO'),
        ),
      ],
    );
  }
}

class _MovementsTab extends ConsumerWidget {
  const _MovementsTab();

  static const _reasons = {
    'orderProduction': 'Used in production',
    'orderCancelled': 'Returned (order cancelled)',
    'purchaseReceived': 'Received from supplier',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inventoryMovementsProvider);
    final fmt = DateFormat('d MMM, HH:mm');
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn\'t load movements',
        message: friendlyError(e),
      ),
      data: (moves) => moves.isEmpty
          ? const EmptyState(
              icon: Icons.swap_vert_rounded,
              title: 'No stock movements yet',
              message:
                  'Production usage, cancellations and deliveries from suppliers are logged here automatically.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final m in moves)
                  ListTile(
                    leading: Icon(
                      m.change < 0
                          ? Icons.remove_circle_outline
                          : Icons.add_circle_outline,
                      color: m.change < 0 ? Colors.deepOrange : Colors.green,
                    ),
                    title: Text(
                      '${m.change > 0 ? '+' : ''}${m.change} ${m.materialName}',
                    ),
                    subtitle: Text(
                      [
                        _reasons[m.reason] ?? m.reason,
                        if (m.reference.isNotEmpty) m.reference,
                        fmt.format(m.at),
                        if (m.shortfall > 0) 'SHORT by ${m.shortfall}',
                      ].join(' · '),
                    ),
                  ),
              ],
            ),
    );
  }
}
