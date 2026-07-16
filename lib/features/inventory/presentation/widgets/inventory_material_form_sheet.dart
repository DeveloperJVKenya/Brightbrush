import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/logging/app_logger.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_material.dart';

Future<void> showInventoryMaterialFormSheet(BuildContext context, WidgetRef ref, {InventoryMaterial? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _InventoryMaterialFormSheet(existing: existing),
  );
}

class _InventoryMaterialFormSheet extends ConsumerStatefulWidget {
  const _InventoryMaterialFormSheet({this.existing});

  final InventoryMaterial? existing;

  @override
  ConsumerState<_InventoryMaterialFormSheet> createState() => _InventoryMaterialFormSheetState();
}

class _InventoryMaterialFormSheetState extends ConsumerState<_InventoryMaterialFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _category = TextEditingController(text: widget.existing?.category ?? '');
  late final _unit = TextEditingController(text: widget.existing?.unit ?? 'pcs');
  late final _quantity = TextEditingController(text: widget.existing?.quantityOnHand.toString() ?? '0');
  late final _reorderPoint = TextEditingController(text: widget.existing?.reorderPoint.toString() ?? '0');
  late final _supplierName = TextEditingController(text: widget.existing?.supplierName ?? '');
  late final _supplierContact = TextEditingController(text: widget.existing?.supplierContact ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _unit.dispose();
    _quantity.dispose();
    _reorderPoint.dispose();
    _supplierName.dispose();
    _supplierContact.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repo = ref.read(inventoryRepositoryProvider);
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      appLogger.w('[inventory] Save attempted with no signed-in uid — this will fail Firestore rules (createdBy required)');
    }

    try {
      final material = InventoryMaterial(
        id: widget.existing?.id ?? '',
        name: _name.text.trim(),
        category: _category.text.trim(),
        unit: _unit.text.trim(),
        quantityOnHand: int.parse(_quantity.text.trim()),
        reorderPoint: int.parse(_reorderPoint.text.trim()),
        supplierName: _supplierName.text.trim(),
        supplierContact: _supplierContact.text.trim(),
        notes: _notes.text.trim(),
        createdBy: widget.existing?.createdBy ?? uid ?? '',
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.existing == null) {
        final id = await repo.create(material, uid: uid ?? '');
        appLogger.i('[inventory] Created material $id (createdBy=$uid)');
      } else {
        await repo.update(material);
        appLogger.i('[inventory] Updated material ${material.id}');
      }

      if (mounted) Navigator.of(context).pop();
    } catch (error, stack) {
      appLogger.e('[inventory] Failed to save material', error: error, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t save: $error'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 4, bottom: MediaQuery.viewInsetsOf(context).bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'Add material' : 'Edit material',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a name (2+ chars)' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _category,
                decoration: const InputDecoration(labelText: 'Category (e.g. paint, blanks, thread)'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a category' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      decoration: const InputDecoration(labelText: 'Qty on hand'),
                      keyboardType: TextInputType.number,
                      validator: (v) => int.tryParse(v ?? '') == null ? 'Whole number' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _reorderPoint,
                      decoration: const InputDecoration(labelText: 'Reorder at'),
                      keyboardType: TextInputType.number,
                      validator: (v) => int.tryParse(v ?? '') == null ? 'Whole number' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supplierName,
                decoration: const InputDecoration(labelText: 'Supplier (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supplierContact,
                decoration: const InputDecoration(labelText: 'Supplier contact (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.existing == null ? 'Add material' : 'Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
