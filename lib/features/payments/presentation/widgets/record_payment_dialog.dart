import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/user_facing_error.dart';
import '../../../../core/formatting/currency.dart';
import '../../../orders/domain/order_model.dart';
import '../../application/payments_providers.dart';
import 'order_payment_panel.dart';

/// Staff record money received outside the app (cash on delivery, bank
/// transfer, a Paybill payment sent directly). It goes through the same
/// server-side ledger as online payments, so the order's paid amount and
/// status stay correct.
Future<void> showRecordPaymentDialog(BuildContext context, OrderModel order) {
  return showDialog<void>(
    context: context,
    builder: (context) => _RecordPaymentDialog(order: order),
  );
}

class _RecordPaymentDialog extends ConsumerStatefulWidget {
  const _RecordPaymentDialog({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_RecordPaymentDialog> createState() =>
      _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<_RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.order.balanceDue.round().toString(),
  );
  final _reference = TextEditingController();
  final _note = TextEditingController();
  String _method = 'mpesaManual';
  bool _saving = false;

  static const _methods = {
    'mpesaManual': 'M-Pesa (Paybill/Till, outside the app)',
    'cash': 'Cash',
    'bankTransfer': 'Bank transfer',
    'cheque': 'Cheque',
    'other': 'Other',
  };

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(paymentsRepositoryProvider)
          .recordManualPayment(
            orderId: widget.order.id,
            amount: int.parse(_amount.text.trim()),
            method: _method,
            reference: _reference.text.trim(),
            note: _note.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded'),
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
    final order = widget.order;
    return AlertDialog(
      title: Text('Payments · ${order.displayNumber}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OrderMoneyBreakdown(order: order),
              const SizedBox(height: 12),
              OrderPaymentHistory(orderId: order.id, asStaff: true),
              if (order.balanceDue > 0) ...[
                const SizedBox(height: 16),
                Text(
                  'Record a payment received',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _method,
                        decoration: const InputDecoration(labelText: 'Method'),
                        items: [
                          for (final e in _methods.entries)
                            DropdownMenuItem(value: e.key, child: Text(e.value)),
                        ],
                        onChanged: (v) => setState(() => _method = v!),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _amount,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Amount (KES)',
                          helperText:
                              'Balance due: ${currencyFormat.format(order.balanceDue)}',
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Enter an amount';
                          if (n > order.balanceDue) {
                            return 'More than the balance due';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _reference,
                        decoration: const InputDecoration(
                          labelText: 'Reference (M-Pesa code, bank ref…)',
                        ),
                        maxLength: 80,
                      ),
                      TextFormField(
                        controller: _note,
                        decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                        ),
                        maxLength: 300,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (order.balanceDue > 0)
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Record payment'),
          ),
      ],
    );
  }
}
