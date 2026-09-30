import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../commerce/application/commerce_providers.dart';
import '../../commerce/data/commerce_repository.dart';
import '../../payments/application/payments_providers.dart';
import '../../payments/domain/business_settings.dart';
import '../application/quotes_providers.dart';
import '../domain/quote_request.dart';
import '../../../shared/whatsapp.dart';
import '../../../l10n/app_localizations.dart';
import 'request_quote_sheet.dart';

/// Customer view of their quote requests: waiting, priced (accept / turn
/// down), and closed ones. Accepting turns the quote into a real order via
/// the acceptQuote function and jumps straight to it for payment.
class MyQuotesScreen extends ConsumerWidget {
  const MyQuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myQuotesProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/customer/orders'),
        ),
        title: const Text('My quotes'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRequestQuoteSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New request'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          appLogger.e('[quotes] load failed', error: error, stackTrace: stack);
          return EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Couldn\'t load your quotes',
            message: friendlyError(error),
            action: TextButton.icon(
              onPressed: () => ref.invalidate(myQuotesProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          );
        },
        data: (quotes) {
          if (quotes.isEmpty) {
            return const EmptyState(
              icon: Icons.request_quote_outlined,
              title: 'No quote requests yet',
              message:
                  'Need a custom job, a big quantity or a package tailored to you? Request a quote.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            itemCount: quotes.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _QuoteCard(quote: quotes[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuoteCard extends ConsumerWidget {
  const _QuoteCard({required this.quote});

  final QuoteRequest quote;

  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final priced = quote.status == QuoteStatus.quoted;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          priced ? 'Turn down this price?' : 'Withdraw this request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(priced ? 'Turn down' : 'Withdraw'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(quotesRepositoryProvider).customerClose(quote);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final date = DateFormat('d MMM y');
    final canAccept =
        quote.status == QuoteStatus.quoted &&
        !quote.isExpired &&
        quote.quotedTotal != null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(quote.status.icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    quote.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    quote.status == QuoteStatus.quoted && quote.isExpired
                        ? 'Expired'
                        : quote.status.label,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${quote.quantity} pcs · requested ${date.format(quote.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
            if (quote.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(quote.details),
            ],
            if (quote.quotedTotal != null &&
                quote.status != QuoteStatus.declined) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Text('Quoted price'),
                  const Spacer(),
                  Text(
                    currencyFormat.format(quote.quotedTotal),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              if (quote.validUntil != null)
                Text(
                  'Valid until ${date.format(quote.validUntil!)} · includes delivery',
                  style: theme.textTheme.bodySmall,
                ),
            ],
            if ((quote.quoteMessage ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(quote.quoteMessage!),
              ),
            ],
            if (quote.status.isOpen || quote.orderId != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canAccept)
                    FilledButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => _AcceptQuoteDialog(quote: quote),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Accept & order'),
                    ),
                  if (quote.quotedTotal != null)
                    TextButton.icon(
                      onPressed: () => openDocument(
                        context,
                        ref,
                        DocumentKind.quote,
                        quote.id,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Quote PDF'),
                    ),
                  WhatsAppUsButton(
                    label: AppLocalizations.of(context).whatsappUs,
                    message: AppLocalizations.of(
                      context,
                    ).waQuoteMessage(quote.title),
                  ),
                  if (quote.orderId != null)
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/customer/orders/${quote.orderId}'),
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: const Text('View order'),
                    ),
                  if (quote.status.isOpen)
                    TextButton(
                      onPressed: () => _close(context, ref),
                      child: Text(
                        quote.status == QuoteStatus.quoted
                            ? 'Turn down'
                            : 'Withdraw',
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AcceptQuoteDialog extends ConsumerStatefulWidget {
  const _AcceptQuoteDialog({required this.quote});

  final QuoteRequest quote;

  @override
  ConsumerState<_AcceptQuoteDialog> createState() => _AcceptQuoteDialogState();
}

class _AcceptQuoteDialogState extends ConsumerState<_AcceptQuoteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.quote.customerName);
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  String _plan = 'full';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _phone.text = ref.read(currentUserProvider)?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final orderId = await ref
          .read(quotesRepositoryProvider)
          .accept(
            quoteId: widget.quote.id,
            contactName: _name.text.trim(),
            contactPhone: _phone.text.trim(),
            deliveryAddress: _address.text.trim(),
            notes: _notes.text.trim(),
            paymentPlan: _plan,
          );
      if (!mounted) return;
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push('/customer/orders/$orderId');
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
    final settings =
        ref.watch(businessSettingsProvider).valueOrNull ??
        const BusinessSettings();
    final pricing = OrderPricing.compute(
      widget.quote.quotedTotal ?? 0,
      settings,
      paymentPlan: _plan,
      includeDelivery: false,
    );
    return AlertDialog(
      title: const Text('Accept quote'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Contact name'),
                  validator: (v) =>
                      (v ?? '').trim().length < 2 ? 'Enter a name' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Contact phone'),
                  validator: (v) => (v ?? '').trim().length < 9
                      ? 'Enter a phone number'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(
                    labelText: 'Delivery address',
                  ),
                  maxLines: 2,
                  validator: (v) =>
                      (v ?? '').trim().length < 5 ? 'Enter an address' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                if (settings.depositsAvailable)
                  SegmentedButton<String>(
                    segments: [
                      const ButtonSegment(
                        value: 'full',
                        label: Text('Pay in full'),
                      ),
                      ButtonSegment(
                        value: 'deposit',
                        label: Text('${settings.depositPercent}% deposit'),
                      ),
                    ],
                    selected: {_plan},
                    onSelectionChanged: (v) => setState(() => _plan = v.first),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    pricing.paymentPlan == 'deposit'
                        ? 'Total ${currencyFormat.format(pricing.total)} · pay ${currencyFormat.format(pricing.depositAmount)} now'
                        : 'Total ${currencyFormat.format(pricing.total)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _accept,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Place order'),
        ),
      ],
    );
  }
}
