import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/logging/app_logger.dart';
import '../../application/assets_providers.dart';
import '../../domain/company_asset.dart';

Future<void> showAssetFormSheet(BuildContext context, WidgetRef ref, {CompanyAsset? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _AssetFormSheet(existing: existing),
  );
}

class _AssetFormSheet extends ConsumerStatefulWidget {
  const _AssetFormSheet({this.existing});

  final CompanyAsset? existing;

  @override
  ConsumerState<_AssetFormSheet> createState() => _AssetFormSheetState();
}

class _AssetFormSheetState extends ConsumerState<_AssetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late AssetCategory _category = widget.existing?.category ?? AssetCategory.equipment;
  late AssetCondition _condition = widget.existing?.condition ?? AssetCondition.operational;
  late DateTime? _purchaseDate = widget.existing?.purchaseDate;

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repo = ref.read(assetsRepositoryProvider);
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      appLogger.w('[assets] Save attempted with no signed-in uid — this will fail Firestore rules (createdBy required)');
    }

    try {
      final asset = CompanyAsset(
        id: widget.existing?.id ?? '',
        name: _name.text.trim(),
        category: _category,
        condition: _condition,
        purchaseDate: _purchaseDate,
        notes: _notes.text.trim(),
        createdBy: widget.existing?.createdBy ?? uid ?? '',
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.existing == null) {
        final id = await repo.create(asset, uid: uid ?? '');
        appLogger.i('[assets] Created asset $id (createdBy=$uid)');
      } else {
        await repo.update(asset);
        appLogger.i('[assets] Updated asset ${asset.id}');
      }

      if (mounted) Navigator.of(context).pop();
    } catch (error, stack) {
      appLogger.e('[assets] Failed to save asset', error: error, stackTrace: stack);
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
                widget.existing == null ? 'Add asset' : 'Edit asset',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a name (2+ chars)' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AssetCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [for (final c in AssetCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
                onChanged: (value) => setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AssetCondition>(
                initialValue: _condition,
                decoration: const InputDecoration(labelText: 'Condition'),
                items: [for (final c in AssetCondition.values) DropdownMenuItem(value: c, child: Text(c.label))],
                onChanged: (value) => setState(() => _condition = value ?? _condition),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_purchaseDate == null ? 'Purchase date (optional)' : 'Purchased ${_purchaseDate!.toLocal()}'.split(' ').first),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDate,
              ),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.existing == null ? 'Add asset' : 'Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
