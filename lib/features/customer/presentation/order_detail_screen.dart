import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/formatting/currency.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/order_status_timeline.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/domain/order_status.dart';
import '../../chat/order_chat.dart';
import '../../commerce/presentation/order_documents_panel.dart';
import '../../growth/social_widgets.dart';
import '../../ops/presentation/order_timeline.dart';
import '../../customization/presentation/widgets/customization_summary.dart';
import '../../payments/presentation/widgets/order_payment_panel.dart';
import '../../proofs/presentation/proof_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/whatsapp.dart';
import '../../../core/l10n/language.dart';
import '../application/cart_providers.dart';
import '../../../core/l10n/l10n_ext.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.paymentOutcome,
  });

  final String orderId;

  /// 'success' / 'cancelled' / 'failed' when the customer lands here
  /// from a hosted checkout (Stripe, PayPal, Flutterwave) redirect.
  final String? paymentOutcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.l10n.back,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(context.l10n.orderDetails),
      ),
      body: ordersAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            semanticsLabel: context.l10n.loading,
          ),
        ),
        error: (error, stack) {
          appLogger.e(
            '[orders] Failed to load order detail',
            error: error,
            stackTrace: stack,
          );
          return EmptyState(
            icon: Icons.cloud_off_rounded,
            title: context.l10n.failedToLoad,
            message: friendlyError(error),
            action: TextButton.icon(
              onPressed: () => ref.invalidate(myOrdersProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.retry),
            ),
          );
        },
        data: (orders) {
          final matches = orders.where((o) => o.id == orderId);
          final order = matches.isEmpty ? null : matches.first;
          if (order == null) {
            return EmptyState(
              icon: Icons.search_off_rounded,
              title: context.l10n.orderNotFound,
              message: context.l10n.itMayHaveBeenRemoved,
            );
          }
          return _OrderDetailBody(order: order, paymentOutcome: paymentOutcome);
        },
      ),
    );
  }
}

class _OrderDetailBody extends ConsumerWidget {
  const _OrderDetailBody({required this.order, this.paymentOutcome});

  final OrderModel order;
  final String? paymentOutcome;

  static const _wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        if (!isWide) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ?_outcomeBanner(context),
              _StatusCard(order: order),
              const SizedBox(height: 16),
              DeliveryCodeCard(order: order),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OrderChatButton(
                  orderId: order.id,
                  orderLabel: order.displayNumber,
                  asStaff: false,
                ),
              ),
              const SizedBox(height: 16),
              CustomerProofPanel(order: order),
              const SizedBox(height: 16),
              OrderPaymentPanel(order: order),
              const SizedBox(height: 16),
              OrderDocumentsPanel(order: order),
              const SizedBox(height: 16),
              _ItemsSection(order: order),
              const SizedBox(height: 16),
              _DeliverySection(order: order),
              const SizedBox(height: 16),
              OrderTimeline(order: order),
            ],
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ?_outcomeBanner(context),
                _StatusCard(order: order),
                const SizedBox(height: 16),
                DeliveryCodeCard(order: order),
                const SizedBox(height: 12),
                OrderReviewCard(order: order),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OrderChatButton(
                        orderId: order.id,
                        orderLabel: order.displayNumber,
                        asStaff: false,
                      ),
                      WhatsAppUsButton(
                        label: AppLocalizations.of(context).whatsappUs,
                        message: AppLocalizations.of(context).waOrderMessage(
                          order.displayNumber,
                          order.status.localized(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          CustomerProofPanel(order: order),
                          const SizedBox(height: 16),
                          _ItemsSection(order: order),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          OrderPaymentPanel(order: order),
                          const SizedBox(height: 16),
                          OrderDocumentsPanel(order: order),
                          const SizedBox(height: 16),
                          _DeliverySection(order: order),
                          const SizedBox(height: 16),
                          OrderTimeline(order: order),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension on _OrderDetailBody {
  /// Result of a hosted-checkout redirect. The ledger is the source of
  /// truth (webhooks can land a few seconds after the redirect), so
  /// "success" is phrased as "confirming" until the order reflects it.
  Widget? _outcomeBanner(BuildContext context) {
    final outcome = paymentOutcome;
    if (outcome == null) return null;
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, text) = switch (outcome) {
      'success' when order.amountPaid > 0 => (
        Icons.check_circle_rounded,
        Colors.green,
        context.l10n.paymentReceivedThankYou,
      ),
      'success' => (
        Icons.hourglass_top_rounded,
        scheme.primary,
        context.l10n.confirmingYourPaymentWithTheProvider,
      ),
      'cancelled' => (
        Icons.info_outline_rounded,
        scheme.onSurfaceVariant,
        context.l10n.paymentCancelledYouCanTryAgain,
      ),
      _ => (
        Icons.error_outline_rounded,
        scheme.error,
        context.l10n.thePaymentDidntGoThroughYou,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(text),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: OrderStatusTimeline(
          status: order.status,
          includeProofStep: order.requiresProof || order.proofVersion > 0,
        ),
      ),
    );
  }
}

class _ItemsSection extends ConsumerWidget {
  const _ItemsSection({required this.order});

  final OrderModel order;

  /// "Order again": same items, artwork, placements and sizes back in the
  /// cart; prices are recalculated at checkout.
  Future<void> _reorder(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final l10n = context.l10n;
    try {
      final added = await ref.read(cartActionsProvider).reorder(order);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? l10n.nothingToReorderQuotedItemsNeed
                : l10n.addedItemSToYourCart(added),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (added > 0) router.go('/customer/cart');
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(friendlyError(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.items,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (order.items.any((i) => i.kind != OrderLineKind.quote))
              TextButton.icon(
                onPressed: () => _reorder(context, ref),
                icon: const Icon(Icons.replay_rounded),
                label: Text(AppLocalizations.of(context).orderAgain),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final item in order.items) ...[
                ListTile(
                  title: Text(item.name),
                  subtitle: item.customization == null
                      ? Text(
                          '${item.quantity} × ${currencyFormat.format(item.unitPrice)}',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.piecesCount(item.quantity) +
                                  ((item.pricing['setupFees'] ?? 0) > 0
                                      ? context.l10n.inclSetup(
                                          currencyFormat.format(
                                            item.pricing['setupFees'],
                                          ),
                                        )
                                      : ''),
                            ),
                            CustomizationSummary(config: item.customization!),
                          ],
                        ),
                  trailing: Text(
                    currencyFormat.format(item.lineTotal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (item != order.items.last) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DeliverySection extends ConsumerStatefulWidget {
  const _DeliverySection({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_DeliverySection> createState() => _DeliverySectionState();
}

class _DeliverySectionState extends ConsumerState<_DeliverySection> {
  bool _cancelling = false;

  OrderModel get order => widget.order;

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.cancelThisOrder),
        content: Text(context.l10n.thisCantBeUndone),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.keepOrder),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.cancelOrder),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _cancelling = true);
    try {
      await ref.read(ordersRepositoryProvider).cancel(order.id);
    } catch (error, stack) {
      appLogger.e(
        '[orders] Failed to cancel order ${order.id}',
        error: error,
        stackTrace: stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.couldntCancel(friendlyError(error))),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.delivery,
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
                _InfoRow(icon: Icons.person_outline, label: order.contactName),
                _InfoRow(icon: Icons.call_outlined, label: order.contactPhone),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: order.deliveryAddress,
                ),
                if (order.notes.isNotEmpty)
                  _InfoRow(icon: Icons.notes_rounded, label: order.notes),
              ],
            ),
          ),
        ),
        if (order.status == OrderStatus.pendingReview &&
            order.amountPaid == 0) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _cancelling ? null : _cancel,
            icon: _cancelling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cancel_outlined),
            label: Text(AppLocalizations.of(context).cancelOrder),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
