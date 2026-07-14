import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../catalog/application/catalog_providers.dart';
import '../../../catalog/domain/package_model.dart';

Future<void> showPackageFormSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _PackageFormSheet(),
  );
}

class _PackageFormSheet extends ConsumerStatefulWidget {
  const _PackageFormSheet();

  @override
  ConsumerState<_PackageFormSheet> createState() => _PackageFormSheetState();
}

class _PackageFormSheetState extends ConsumerState<_PackageFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _season = TextEditingController();
  final _price = TextEditingController();
  bool _isActive = true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _season.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = ref.read(ensureSignedInProvider).value?.uid ?? '';
      await ref.read(packagesRepositoryProvider).create(
            PackageModel(
              id: '',
              name: _name.text.trim(),
              description: _description.text.trim(),
              season: _season.text.trim(),
              price: num.parse(_price.text.trim()),
              imageUrl: null,
              itemIds: const [],
              isActive: _isActive,
              validFrom: null,
              validTo: null,
              createdBy: uid,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            uid: uid,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
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
              Text('Add seasonal package', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a name (2+ chars)' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _season,
                decoration: const InputDecoration(labelText: 'Season / campaign tag (e.g. valentines)'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a tag (2+ chars)' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                decoration: const InputDecoration(labelText: 'Price (UGX)'),
                keyboardType: TextInputType.number,
                validator: (v) => num.tryParse(v ?? '') == null ? 'Number' : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active (visible to customers)'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add package'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
