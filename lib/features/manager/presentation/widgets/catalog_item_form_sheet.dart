import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../catalog/application/catalog_providers.dart';
import '../../../catalog/domain/catalog_category.dart';
import '../../../catalog/domain/catalog_item.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/errors/user_facing_error.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../inventory/application/inventory_providers.dart';
import 'customization_options_editor.dart';

/// Create/edit form for a catalog item. Image upload degrades gracefully:
/// if Storage isn't activated on the project yet, the item still saves —
/// just without a photo — rather than blocking the whole form on it.
Future<void> showCatalogItemFormSheet(
  BuildContext context,
  WidgetRef ref, {
  CatalogItem? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => _CatalogItemFormSheet(existing: existing),
  );
}

class _CatalogItemFormSheet extends ConsumerStatefulWidget {
  const _CatalogItemFormSheet({this.existing});

  final CatalogItem? existing;

  @override
  ConsumerState<_CatalogItemFormSheet> createState() =>
      _CatalogItemFormSheetState();
}

class _CatalogItemFormSheetState extends ConsumerState<_CatalogItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _price = TextEditingController(
    text: widget.existing?.basePrice.toString() ?? '',
  );
  late final _moq = TextEditingController(
    text: widget.existing?.moq.toString() ?? '1',
  );
  late final _leadTime = TextEditingController(
    text: widget.existing?.leadTimeDays.toString() ?? '3',
  );
  late final _tags = TextEditingController(
    text: widget.existing?.tags.join(', ') ?? '',
  );
  late CatalogCategory _category =
      widget.existing?.category ?? CatalogCategory.tshirts;
  late bool _isActive = widget.existing?.isActive ?? true;
  late bool _isFeatured = widget.existing?.isFeatured ?? false;
  late List<MaterialUse> _materials = [...?widget.existing?.materials];
  late CustomizationOptionsValue _options = CustomizationOptionsValue(
    priceTiers: widget.existing?.priceTiers ?? const [],
    sizes: widget.existing?.sizes ?? const [],
    colours: widget.existing?.colours ?? const [],
    decorationMethods: widget.existing?.decorationMethods ?? const [],
    placements: widget.existing?.placements ?? const [],
  );

  Uint8List? _pickedImageBytes;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _moq.dispose();
    _leadTime.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _pickedImageBytes = bytes);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final tags = _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .take(15)
        .toList();

    var imageUrls = widget.existing?.imageUrls ?? const <String>[];
    final repo = ref.read(catalogRepositoryProvider);
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      appLogger.w(
        '[catalog] Save attempted with no signed-in uid — this will fail Firestore rules (createdBy required)',
      );
    }

    try {
      final base = CatalogItem(
        id: widget.existing?.id ?? '',
        name: _name.text.trim(),
        category: _category,
        description: _description.text.trim(),
        basePrice: num.parse(_price.text.trim()),
        moq: int.parse(_moq.text.trim()),
        leadTimeDays: int.parse(_leadTime.text.trim()),
        imageUrls: imageUrls,
        tags: tags,
        isActive: _isActive,
        isFeatured: _isFeatured,
        createdBy: widget.existing?.createdBy ?? uid ?? '',
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        priceTiers: _options.priceTiers,
        sizes: _options.sizes,
        colours: _options.colours,
        decorationMethods: _options.decorationMethods,
        placements: _options.placements,
        materials: _materials,
      );

      String itemId;
      if (widget.existing == null) {
        itemId = await repo.create(base, uid: uid ?? '');
        appLogger.i('[catalog] Created item $itemId (createdBy=$uid)');
      } else {
        itemId = widget.existing!.id;
        await repo.update(base);
        appLogger.i('[catalog] Updated item $itemId');
      }

      if (_pickedImageBytes != null) {
        try {
          final uploader = ref.read(catalogImageUploaderProvider);
          final url = await uploader.uploadCatalogItemImage(
            itemId: itemId,
            bytes: _pickedImageBytes!,
            contentType: 'image/jpeg',
          );
          await repo.update(
            base.copyWith(
              id: itemId,
              imageUrls: [...imageUrls, url],
              updatedAt: DateTime.now(),
            ),
          );
        } catch (error, stack) {
          appLogger.w(
            '[catalog] Image upload failed for item $itemId — saved without a photo',
            error: error,
            stackTrace: stack,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Saved without a photo — Storage isn\'t activated on this project yet.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              widget.existing == null ? 'Item added' : 'Item updated',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error, stack) {
      appLogger.e(
        '[catalog] Failed to save catalog item',
        error: error,
        stackTrace: stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Couldn\'t save: ${friendlyError(error)}'),
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
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null
                    ? 'Add catalog item'
                    : 'Edit catalog item',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _pickedImageBytes != null
                      ? Image.memory(
                          _pickedImageBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add a photo (optional)',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Enter a name (2+ chars)'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CatalogCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in CatalogCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      decoration: const InputDecoration(
                        labelText: 'Base price (KES)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = num.tryParse(v ?? '');
                        if (n == null) return 'Number';
                        if (n <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _moq,
                      decoration: const InputDecoration(labelText: 'MOQ'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null) return 'Whole number';
                        if (n < 1) return 'Must be at least 1';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _leadTime,
                      decoration: const InputDecoration(labelText: 'Lead days'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null) return 'Whole number';
                        if (n < 0) return 'Can\'t be negative';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                ),
              ),
              _BomEditor(
                materials: _materials,
                onChanged: (v) => setState(() => _materials = v),
              ),
              CustomizationOptionsEditor(
                value: _options,
                category: _category,
                onChanged: (v) => setState(() => _options = v),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active (visible to customers)'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Featured'),
                value: _isFeatured,
                onChanged: (v) => setState(() => _isFeatured = v),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.existing == null ? 'Add item' : 'Save changes',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Materials used per piece" — lets the server deduct stock automatically
/// when an order for this item enters production.
class _BomEditor extends ConsumerWidget {
  const _BomEditor({required this.materials, required this.onChanged});

  final List<MaterialUse> materials;
  final ValueChanged<List<MaterialUse>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stock =
        ref.watch(allInventoryMaterialsProvider).valueOrNull ?? const [];
    final byId = {for (final m in stock) m.id: m};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),
        Text('Materials used per piece', style: theme.textTheme.labelLarge),
        Text(
          'Deducted from stock automatically when an order goes into production.',
          style: theme.textTheme.bodySmall,
        ),
        for (final (i, m) in materials.indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(byId[m.materialId]?.name ?? 'Removed material'),
            subtitle: Text(
              '${m.perUnit} ${byId[m.materialId]?.unit ?? ''} per piece',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => onChanged([...materials]..removeAt(i)),
            ),
          ),
        TextButton.icon(
          onPressed: stock.isEmpty
              ? null
              : () async {
                  var picked = stock.first;
                  final qty = TextEditingController(text: '1');
                  final use = await showDialog<MaterialUse>(
                    context: context,
                    builder: (context) => StatefulBuilder(
                      builder: (context, setState) => AlertDialog(
                        title: const Text('Material per piece'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonFormField(
                              initialValue: picked,
                              isExpanded: true,
                              items: [
                                for (final m in stock)
                                  DropdownMenuItem(
                                    value: m,
                                    child: Text('${m.name} (${m.unit})'),
                                  ),
                              ],
                              onChanged: (v) => setState(() => picked = v!),
                            ),
                            TextField(
                              controller: qty,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Amount per piece',
                                helperText:
                                    'e.g. 1 blank cap, 0.05 cone of thread',
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () {
                              final n = num.tryParse(qty.text.trim());
                              if (n == null || n <= 0) return;
                              Navigator.pop(
                                context,
                                MaterialUse(materialId: picked.id, perUnit: n),
                              );
                            },
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (use != null) {
                    onChanged([
                      ...materials.where((m) => m.materialId != use.materialId),
                      use,
                    ]);
                  }
                },
          icon: const Icon(Icons.add_rounded),
          label: Text(
            stock.isEmpty
                ? 'Add stock materials under Inventory first'
                : 'Add material',
          ),
        ),
      ],
    );
  }
}
