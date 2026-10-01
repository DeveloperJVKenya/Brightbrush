import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/user_facing_error.dart';
import '../../../../core/formatting/currency.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../orders/domain/order_model.dart';
import '../../../orders/domain/order_status.dart';
import '../../application/payments_providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/payment_models.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/l10n/enum_l10n.dart';

/// Price breakdown for an order: subtotal, delivery, VAT, total, paid and
/// balance. Shared by the customer order page and staff views.
class OrderMoneyBreakdown extends StatelessWidget {
  const OrderMoneyBreakdown({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vatPercent = (order.taxRate * 100).toStringAsFixed(0);
    final vatInclusive = order.total == order.subtotal + order.deliveryFee;
    Widget row(String label, num value, {bool bold = false, Color? color}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: bold
                    ? const TextStyle(fontWeight: FontWeight.w700)
                    : null,
              ),
            ),
            Text(
              currencyFormat.format(value),
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        row(context.l10n.subtotal, order.subtotal),
        if (order.corporateDiscount > 0)
          row(context.l10n.accountDiscount2, -order.corporateDiscount),
        if (order.couponDiscount > 0)
          row(
            context.l10n.promo(order.couponCode ?? ''),
            -order.couponDiscount,
          ),
        if (order.deliveryFee > 0)
          row(
            order.deliveryZoneName == null
                ? context.l10n.delivery
                : context.l10n.delivery2(order.deliveryZoneName!),
            order.deliveryFee,
          ),
        if (order.isPickup) row(context.l10n.storePickup, 0),
        if (order.taxAmount > 0)
          row(
            vatInclusive
                ? context.l10n.includesVat2(vatPercent)
                : context.l10n.vat2(vatPercent),
            order.taxAmount,
          ),
        const Divider(),
        row(
          context.l10n.total,
          order.total,
          bold: true,
          color: theme.colorScheme.primary,
        ),
        if (order.amountPaid > 0) row(context.l10n.paid, order.amountPaid),
        if (order.refundedAmount > 0)
          row(context.l10n.refunded, -order.refundedAmount),
        if (order.cancellationFee > 0)
          row(context.l10n.cancellationFeeKept, order.cancellationFee),
        if (order.isCredit && order.dueDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              order.overdue
                  ? context.l10n.overdueWasDue(
                      DateFormat('d MMM y').format(order.dueDate!),
                    )
                  : context.l10n.onAccountDue(
                      DateFormat('d MMM y').format(order.dueDate!),
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: order.overdue ? theme.colorScheme.error : null,
              ),
            ),
          ),
        if (order.amountPaid > 0 || order.isDepositPlan)
          row(context.l10n.balanceDue, order.balanceDue, bold: true),
        if (order.isDepositPlan)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(
                  order.depositCovered
                      ? Icons.verified_rounded
                      : Icons.info_outline_rounded,
                  size: 16,
                  color: order.depositCovered
                      ? Colors.green
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.depositCovered
                        ? context.l10n.depositReceivedProductionCanStart
                        : context.l10n.depositOfDueBeforeProductionStarts(
                            currencyFormat.format(order.depositAmount),
                          ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The customer's "Pay" section on an order: available gateways, deposit vs
/// balance choice, M-Pesa phone entry, and the payment history. Everything
/// charged is decided by the server; this widget only picks the gateway and
/// whether to pay the deposit or the whole balance.
class OrderPaymentPanel extends ConsumerStatefulWidget {
  const OrderPaymentPanel({super.key, required this.order});

  final OrderModel order;

  @override
  ConsumerState<OrderPaymentPanel> createState() => _OrderPaymentPanelState();
}

class _OrderPaymentPanelState extends ConsumerState<OrderPaymentPanel> {
  PaymentGatewayId? _selected;
  String _amountChoice = 'deposit';
  late final _phone = TextEditingController(text: widget.order.contactPhone);
  bool _starting = false;

  OrderModel get order => widget.order;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  num get _amountForChoice {
    if (_amountChoice == 'deposit' &&
        order.isDepositPlan &&
        !order.depositCovered) {
      final remaining = order.depositAmount - order.amountPaid;
      return remaining < order.balanceDue ? remaining : order.balanceDue;
    }
    return order.balanceDue;
  }

  Future<void> _pay() async {
    final gateway = _selected;
    if (gateway == null) return;
    setState(() => _starting = true);
    try {
      final result = await ref
          .read(paymentsRepositoryProvider)
          .initiatePayment(
            orderId: order.id,
            gateway: gateway,
            amountChoice: _amountChoice == 'deposit' && !order.depositCovered
                ? 'deposit'
                : 'balance',
            phone: gateway == PaymentGatewayId.mpesa
                ? _phone.text.trim()
                : null,
          );
      if (!mounted) return;
      if (result.action == 'stk') {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _MpesaWaitingDialog(
            orderId: order.id,
            paymentId: result.paymentId,
            amount: result.amount,
            message: result.message,
          ),
        );
      } else if (result.redirectUrl != null) {
        final launched = await launchUrl(
          Uri.parse(result.redirectUrl!),
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_self',
        );
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.couldntOpenThePaymentPage),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gateways = ref.watch(availableGatewaysProvider);
    final canPay =
        order.status != OrderStatus.cancelled && order.balanceDue > 0;
    final selected = gateways.any((g) => g.id == _selected)
        ? _selected
        : (gateways.isEmpty ? null : gateways.first.id);
    _selected = selected;
    final selectedInfo = gateways.where((g) => g.id == selected).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.payment,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      avatar: const Icon(Icons.payments_outlined, size: 16),
                      label: Text(order.paymentStatus.tr(context)),
                      visualDensity: VisualDensity.compact,
                    ),
                    const Spacer(),
                    Text(
                      order.displayNumber,
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OrderMoneyBreakdown(order: order),
                if (canPay) ...[
                  const SizedBox(height: 16),
                  if (gateways.isEmpty)
                    Text(
                      context.l10n.onlinePaymentIsntAvailableYetWell,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else ...[
                    if (order.isDepositPlan && !order.depositCovered) ...[
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'deposit',
                            label: Text(
                              context.l10n.deposit2(
                                currencyFormat.format(
                                  order.depositAmount - order.amountPaid,
                                ),
                              ),
                            ),
                          ),
                          ButtonSegment(
                            value: 'balance',
                            label: Text(
                              context.l10n.full(
                                currencyFormat.format(order.balanceDue),
                              ),
                            ),
                          ),
                        ],
                        selected: {_amountChoice},
                        onSelectionChanged: (v) =>
                            setState(() => _amountChoice = v.first),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      AppLocalizations.of(context).payWith,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final g in gateways)
                          ChoiceChip(
                            avatar: Icon(g.id.icon, size: 18),
                            label: Text(g.displayName),
                            selected: g.id == selected,
                            onSelected: (_) => setState(() => _selected = g.id),
                          ),
                      ],
                    ),
                    if (selected == PaymentGatewayId.mpesa) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: context.l10n.mPesaPhoneNumber,
                          hintText: '07XX XXX XXX',
                          prefixIcon: Icon(Icons.phone_android_rounded),
                        ),
                      ),
                    ],
                    if (selectedInfo?.isSandbox ?? false) ...[
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.testModeNoRealMoneyWill,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _starting || selected == null ? null : _pay,
                        icon: _starting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.lock_rounded),
                        label: Text(
                          context.l10n.payAmount(
                            currencyFormat.format(_amountForChoice),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        OrderPaymentHistory(orderId: order.id, asStaff: false),
      ],
    );
  }
}

/// Every payment attempt on an order, with a "check status" action on
/// pending ones (recovers lost callbacks / closed checkout tabs).
/// Staff and customers both use this under an order; staff pass `asStaff`
/// so they see every attempt, not just their own.
class OrderPaymentHistory extends ConsumerWidget {
  const OrderPaymentHistory({
    super.key,
    required this.orderId,
    required this.asStaff,
  });

  final String orderId;
  final bool asStaff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments =
        ref
            .watch(orderPaymentsProvider((orderId: orderId, asStaff: asStaff)))
            .valueOrNull ??
        const <PaymentRecord>[];
    if (payments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PaymentHistoryList(payments: payments),
    );
  }
}

class PaymentHistoryList extends ConsumerWidget {
  const PaymentHistoryList({super.key, required this.payments});

  final List<PaymentRecord> payments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMM y, HH:mm');
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final p in payments)
            ListTile(
              dense: true,
              leading: Icon(
                p.status.icon,
                color: switch (p.status) {
                  PaymentState.succeeded => Colors.green,
                  PaymentState.failed => theme.colorScheme.error,
                  _ => theme.colorScheme.onSurfaceVariant,
                },
              ),
              title: Text(
                '${p.gatewayLabel} · ${currencyFormat.format(p.amount)}',
              ),
              subtitle: Text(
                [
                  '${p.status.tr(context)} · ${dateFormat.format(p.createdAt)}',
                  if (p.receipt != null && p.receipt!.isNotEmpty)
                    context.l10n.ref(p.receipt!),
                  if (p.chargedCurrency != null && p.chargedCurrency != 'KES')
                    context.l10n.charged(
                      p.chargedCurrency!,
                      p.chargedAmount ?? '',
                    ),
                  if (p.message != null &&
                      p.message!.isNotEmpty &&
                      p.status != PaymentState.succeeded)
                    p.message!,
                ].join('\n'),
              ),
              isThreeLine: true,
              trailing:
                  p.status == PaymentState.pending && p.gateway != 'manual'
                  ? IconButton(
                      tooltip: context.l10n.checkStatus,
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: () async {
                        try {
                          await ref
                              .read(paymentsRepositoryProvider)
                              .refreshStatus(p.id);
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
                      },
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

/// Shown after an STK push: watches the Payments doc live (the Daraja
/// callback updates it) and offers a manual status check.
class _MpesaWaitingDialog extends ConsumerStatefulWidget {
  const _MpesaWaitingDialog({
    required this.orderId,
    required this.paymentId,
    required this.amount,
    required this.message,
  });

  final String orderId;
  final String paymentId;
  final num amount;
  final String message;

  @override
  ConsumerState<_MpesaWaitingDialog> createState() =>
      _MpesaWaitingDialogState();
}

class _MpesaWaitingDialogState extends ConsumerState<_MpesaWaitingDialog> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      await ref
          .read(paymentsRepositoryProvider)
          .refreshStatus(widget.paymentId);
    } catch (error, stack) {
      appLogger.w(
        '[payments] STK status check failed',
        error: error,
        stackTrace: stack,
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments =
        ref
            .watch(
              orderPaymentsProvider((orderId: widget.orderId, asStaff: false)),
            )
            .valueOrNull ??
        const <PaymentRecord>[];
    final payment = payments.where((p) => p.id == widget.paymentId).firstOrNull;
    final state = payment?.status ?? PaymentState.pending;

    return AlertDialog(
      icon: Icon(
        state.icon,
        size: 40,
        color: state == PaymentState.succeeded ? Colors.green : null,
      ),
      title: Text(switch (state) {
        PaymentState.pending => context.l10n.checkYourPhone,
        PaymentState.succeeded => context.l10n.paymentReceived,
        PaymentState.failed => context.l10n.paymentFailed,
        PaymentState.cancelled => context.l10n.paymentCancelled,
      }),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(switch (state) {
            PaymentState.pending => context.l10n.amount(
              widget.message,
              currencyFormat.format(widget.amount),
            ),
            PaymentState.succeeded => context.l10n.thankYouReceived(
              currencyFormat.format(widget.amount),
              payment?.receipt != null
                  ? context.l10n.mpesaRefSuffix(payment!.receipt!)
                  : '',
            ),
            _ => payment?.message ?? context.l10n.thePaymentDidNotGoThrough,
          }, textAlign: TextAlign.center),
          if (state == PaymentState.pending) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ],
      ),
      actions: [
        if (state == PaymentState.pending)
          TextButton(
            onPressed: _checking ? null : _check,
            child: Text(context.l10n.ivePaidCheck),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            state == PaymentState.pending
                ? context.l10n.close
                : context.l10n.done,
          ),
        ),
      ],
    );
  }
}
