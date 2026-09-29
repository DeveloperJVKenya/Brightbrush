import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/formatting/currency.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/domain/order_status.dart';
import '../application/commerce_providers.dart';

/// Staff: refund part of what was paid, or cancel the order keeping a
/// cancellation fee. Card/PayPal/Flutterwave payments are refunded through
/// the provider automatically; M-Pesa/cash/bank refunds are recorded for
/// staff to pay out. A credit note is issued either way.
Future<void> showRefundDialog(BuildContext context, OrderModel order) {
  return showDialog<void>(
    context: context,
    builder: (context) => _RefundDialog(order: order),
  );
}

class _RefundDialog extends ConsumerStatefulWidget {
  const _RefundDialog({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends ConsumerState<_RefundDialog> {
  final _reason = TextEditingController();
  late final _amount = TextEditingController(
    text: '${widget.order.netPaid.round()}',
  );
  final _fee = TextEditingController(text: '0');
  late bool _cancel = widget.order.status != OrderStatus.completed;
  bool _busy = false;
  Map<String, dynamic>? _result;

  OrderModel get order => widget.order;

  @override
  void dispose() {
    _reason.dispose();
    _amount.dispose();
    _fee.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Give a reason (it appears on the credit note).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(commerceRepositoryProvider)
          .issueRefund(
            orderId: order.id,
            reason: _reason.text.trim(),
            amount: _cancel ? null : int.tryParse(_amount.text.trim()),
            cancelOrder: _cancel,
            cancellationFee: _cancel
                ? (int.tryParse(_fee.text.trim()) ?? 0)
                : 0,
          );
      setState(() => _result = result);
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
    final result = _result;
    if (result != null) {
      final allocations = [
        for (final a in (result['allocations'] as List? ?? const []))
          Map<String, dynamic>.from(a as Map),
      ];
      return AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Colors.green,
          size: 40,
        ),
        title: Text('Credit note ${result['creditNoteNumber']}'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Refunded ${currencyFormat.format(result['refunded'] ?? 0)}.',
              ),
              for (final a in allocations)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(switch (a['status']) {
                    'refunded' => Icons.check_rounded,
                    'failed' => Icons.error_outline_rounded,
                    _ => Icons.pan_tool_alt_outlined,
                  }),
                  title: Text(
                    '${a['gateway']} · ${currencyFormat.format(a['amount'] ?? 0)}',
                  ),
                  subtitle: Text('${a['message'] ?? ''}'),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      );
    }
    final canCancel =
        order.status != OrderStatus.completed &&
        order.status != OrderStatus.cancelled;
    return AlertDialog(
      title: Text('Refund · ${order.displayNumber}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paid so far: ${currencyFormat.format(order.netPaid)}',
                style: theme.textTheme.titleSmall,
              ),
              if (canCancel)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cancel the order'),
                  subtitle: const Text(
                    'Refunds what was paid minus any cancellation fee.',
                  ),
                  value: _cancel,
                  onChanged: (v) => setState(() => _cancel = v),
                ),
              if (_cancel && canCancel)
                TextField(
                  controller: _fee,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Cancellation fee to keep (KES)',
                    helperText: 'e.g. digitizing or materials already used',
                  ),
                )
              else
                TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Amount to refund (KES)',
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _reason,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Reason (on the credit note)',
                ),
              ),
              Text(
                'Card, PayPal and Flutterwave payments are refunded automatically. '
                'M-Pesa, cash and bank payments must be sent back by staff.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          onPressed: _busy ? null : _submit,
          child: Text(_cancel && canCancel ? 'Cancel & refund' : 'Refund'),
        ),
      ],
    );
  }
}
