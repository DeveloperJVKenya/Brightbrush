import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../support/application/support_providers.dart';
import '../../support/domain/support_ticket.dart';

class CustomerSupportScreen extends ConsumerStatefulWidget {
  const CustomerSupportScreen({super.key});

  @override
  ConsumerState<CustomerSupportScreen> createState() => _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends ConsumerState<CustomerSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    final profile = ref.read(myProfileProvider).valueOrNull;
    if (uid == null) return;

    setState(() => _sending = true);
    try {
      await ref.read(supportTicketsRepositoryProvider).create(
            SupportTicket(
              id: '',
              subject: _subject.text.trim(),
              message: _message.text.trim(),
              customerId: uid,
              customerName: profile?.displayName.isNotEmpty == true ? profile!.displayName : (profile?.email ?? ''),
              status: TicketStatus.open,
              response: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            customerId: uid,
            customerName: profile?.displayName.isNotEmpty == true ? profile!.displayName : (profile?.email ?? ''),
          );
      _subject.clear();
      _message.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket sent — we\'ll get back to you here.'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (error) {
      appLogger.e('[support] Failed to submit ticket', error: error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t send: ${friendlyError(error)}'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ticketsAsync = ref.watch(myTicketsProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Support', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Tell us about an order, a design, or a complaint.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _subject,
                      decoration: const InputDecoration(labelText: 'Subject'),
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a subject' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _message,
                      decoration: const InputDecoration(labelText: 'Message'),
                      maxLines: 4,
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a message' : null,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _sending ? null : _submit,
                        child: _sending
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Send'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('Your tickets', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ticketsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                appLogger.e('[support] Failed to load tickets', error: error, stackTrace: stack);
                return EmptyState(
                    icon: Icons.cloud_off_rounded, title: 'Couldn\'t load tickets', message: friendlyError(error));
              },
              data: (tickets) {
                if (tickets.isEmpty) {
                  return const EmptyState(
                    icon: Icons.support_agent_outlined,
                    title: 'No tickets yet',
                    message: 'Anything you send above will show up here with our reply.',
                  );
                }
                return Column(children: [for (final ticket in tickets) _TicketCard(ticket: ticket)]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final SupportTicket ticket;

  static final _date = DateFormat('MMM d, y');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (ticket.status) {
      TicketStatus.open => Colors.orange,
      TicketStatus.inProgress => theme.colorScheme.primary,
      TicketStatus.resolved => Colors.green,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(ticket.subject, style: const TextStyle(fontWeight: FontWeight.w700))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text(ticket.status.label, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_date.format(ticket.createdAt), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(ticket.message),
            if (ticket.response != null && ticket.response!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
                width: double.infinity,
                child: Text('BrightBrush: ${ticket.response}', style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
