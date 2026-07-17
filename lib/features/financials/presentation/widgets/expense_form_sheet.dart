import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/errors/user_facing_error.dart';
import '../../../../core/logging/app_logger.dart';
import '../../application/financials_providers.dart';
import '../../domain/expense_model.dart';

Future<void> showExpenseFormSheet(BuildContext context, WidgetRef ref, {ExpenseModel? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ExpenseFormSheet(existing: existing),
  );
}

class _ExpenseFormSheet extends ConsumerStatefulWidget {
  const _ExpenseFormSheet({this.existing});

  final ExpenseModel? existing;

  @override
  ConsumerState<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.existing?.amount.toString() ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late ExpenseCategory _category = widget.existing?.category ?? ExpenseCategory.misc;
  late DateTime _date = widget.existing?.date ?? DateTime.now();

  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repo = ref.read(expensesRepositoryProvider);
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      appLogger.w('[expenses] Save attempted with no signed-in uid — this will fail Firestore rules (createdBy required)');
    }

    try {
      final expense = ExpenseModel(
        id: widget.existing?.id ?? '',
        category: _category,
        amount: num.parse(_amount.text.trim()),
        note: _note.text.trim(),
        date: _date,
        createdBy: widget.existing?.createdBy ?? uid ?? '',
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.existing == null) {
        final id = await repo.create(expense, uid: uid ?? '');
        appLogger.i('[expenses] Created expense $id (createdBy=$uid)');
      } else {
        await repo.update(expense);
        appLogger.i('[expenses] Updated expense ${expense.id}');
      }

      if (mounted) Navigator.of(context).pop();
    } catch (error, stack) {
      appLogger.e('[expenses] Failed to save expense', error: error, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t save: ${friendlyError(error)}'), behavior: SnackBarBehavior.floating),
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
                widget.existing == null ? 'Add expense' : 'Edit expense',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ExpenseCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [for (final c in ExpenseCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
                onChanged: (value) => setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                decoration: const InputDecoration(labelText: 'Amount (KES)'),
                keyboardType: TextInputType.number,
                validator: (v) => num.tryParse(v ?? '') == null ? 'Number' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Date: ${_date.toLocal()}'.split(' ').first),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDate,
              ),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.existing == null ? 'Add expense' : 'Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
