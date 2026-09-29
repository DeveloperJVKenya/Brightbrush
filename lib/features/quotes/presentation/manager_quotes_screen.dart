import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../application/quotes_providers.dart';
import '../domain/quote_request.dart';

/// Manager/Admin quote inbox: price new requests (or re-price unaccepted
/// ones), or decline them. Accepted quotes show up as normal orders.
class ManagerQuotesScreen extends ConsumerStatefulWidget {
  const ManagerQuotesScreen({super.key});

  @override
  ConsumerState<ManagerQuotesScreen> createState() =>
      _ManagerQuotesScreenState();
}

class _ManagerQuotesScreenState extends ConsumerState<ManagerQuotesScreen> {
  bool _openOnly = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(allQuotesProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(
          'Quote requests',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Custom jobs and package requests waiting for a price.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Open')),
            ButtonSegment(value: false, label: Text('All')),
          ],
          selected: {_openOnly},
          onSelectionChanged: (v) => setState(() => _openOnly = v.first),
        ),
        const SizedBox(height: 12),
        ...async.when(
          loading: () => const [
            Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (error, stack) {
            appLogger.e(
              '[quotes] inbox failed',
              error: error,
              stackTrace: stack,
            );
            return [
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Couldn\'t load quotes',
                message: friendlyError(error),
              ),
            ];
          },
          data: (quotes) {
            final shown = _openOnly
                ? quotes.where((q) => q.status.isOpen).toList()
                : quotes;
            if (shown.isEmpty) {
              return const [
                EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Nothing waiting',
                  message: 'New quote requests from customers appear here.',
                ),
              ];
            }
            return [
              for (final q in shown) ...[
                _InboxCard(quote: q),
                const SizedBox(height: 10),
              ],
            ];
          },
        ),
      ],
    );
  }
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({required this.quote});

  final QuoteRequest quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateFormat('d MMM y, HH:mm');
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    quote.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  avatar: Icon(quote.status.icon, size: 16),
                  label: Text(
                    quote.status.label.replaceFirst('You', 'Customer'),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              '${quote.customerName}${quote.customerEmail.isNotEmpty ? ' · ${quote.customerEmail}' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              '${quote.quantity} pcs · ${date.format(quote.createdAt)}${quote.packageId != null ? ' · from a package' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            if (quote.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(quote.details),
            ],
            if (quote.quotedTotal != null) ...[
              const SizedBox(height: 8),
              Text(
                'Quoted ${currencyFormat.format(quote.quotedTotal)}'
                '${quote.validUntil != null ? ' · valid to ${DateFormat('d MMM').format(quote.validUntil!)}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            if (quote.status.isOpen) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => _RespondDialog(quote: quote),
                    ),
                    icon: const Icon(Icons.request_quote_rounded),
                    label: Text(
                      quote.status == QuoteStatus.quoted
                          ? 'Re-price'
                          : 'Send price',
                    ),
                  ),
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) =>
                          _RespondDialog(quote: quote, decline: true),
                    ),
                    child: const Text('Decline'),
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

class _RespondDialog extends ConsumerStatefulWidget {
  const _RespondDialog({required this.quote, this.decline = false});

  final QuoteRequest quote;
  final bool decline;

  @override
  ConsumerState<_RespondDialog> createState() => _RespondDialogState();
}

class _RespondDialogState extends ConsumerState<_RespondDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _total = TextEditingController(
    text: widget.quote.quotedTotal?.toString() ?? '',
  );
  late final _message = TextEditingController(
    text: widget.quote.quoteMessage ?? '',
  );
  int _validDays = 14;
  bool _saving = false;

  @override
  void dispose() {
    _total.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(quotesRepositoryProvider);
      if (widget.decline) {
        await repo.decline(
          quoteId: widget.quote.id,
          staffUid: uid,
          message: _message.text.trim(),
        );
      } else {
        await repo.respond(
          quoteId: widget.quote.id,
          staffUid: uid,
          quotedTotal: int.parse(_total.text.trim()),
          message: _message.text.trim(),
          validUntil: DateTime.now().add(Duration(days: _validDays)),
        );
      }
      if (mounted) Navigator.pop(context);
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
    return AlertDialog(
      title: Text(widget.decline ? 'Decline request' : 'Send a price'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.decline) ...[
                TextFormField(
                  controller: _total,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Total price (KES, including delivery)',
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n <= 0 ? 'Enter a price' : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _validDays,
                  decoration: const InputDecoration(labelText: 'Valid for'),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 days')),
                    DropdownMenuItem(value: 14, child: Text('14 days')),
                    DropdownMenuItem(value: 30, child: Text('30 days')),
                  ],
                  onChanged: (v) => setState(() => _validDays = v!),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _message,
                decoration: InputDecoration(
                  labelText: widget.decline
                      ? 'Reason (shown to the customer)'
                      : 'Message (lead time, what\'s included…)',
                ),
                maxLines: 4,
                maxLength: 2000,
                validator: (v) => widget.decline && (v ?? '').trim().isEmpty
                    ? 'Give the customer a reason'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(widget.decline ? 'Decline' : 'Send price'),
        ),
      ],
    );
  }
}
