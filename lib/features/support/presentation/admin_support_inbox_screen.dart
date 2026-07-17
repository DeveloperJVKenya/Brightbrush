import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../application/support_providers.dart';
import '../domain/support_ticket.dart';
import 'widgets/ticket_triage_sheet.dart';

/// Not a persistent nav item — reachable via the Executive Dashboard's
/// "Support Inbox" quick link. Lets Admin/CEO/Developer see and respond to
/// tickets customers raise from /customer/support.
class AdminSupportInboxScreen extends ConsumerWidget {
  const AdminSupportInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ticketsAsync = ref.watch(allTicketsProvider);

    return DefaultTabController(
      length: 3,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Support inbox', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Tickets customers raise from Support, triaged by status.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const TabBar(tabs: [Tab(text: 'Open'), Tab(text: 'In progress'), Tab(text: 'Resolved')]),
            Expanded(
              child: ticketsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) {
                  appLogger.e('[support] Failed to load tickets', error: error, stackTrace: stack);
                  return EmptyState(
                      icon: Icons.cloud_off_rounded, title: 'Couldn\'t load tickets', message: friendlyError(error));
                },
                data: (tickets) {
                  return TabBarView(
                    children: [
                      _TicketList(tickets: tickets.where((t) => t.status == TicketStatus.open).toList()),
                      _TicketList(tickets: tickets.where((t) => t.status == TicketStatus.inProgress).toList()),
                      _TicketList(tickets: tickets.where((t) => t.status == TicketStatus.resolved).toList()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketList extends ConsumerWidget {
  const _TicketList({required this.tickets});

  final List<SupportTicket> tickets;

  static final _date = DateFormat('MMM d, y · h:mm a');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tickets.isEmpty) {
      return const EmptyState(icon: Icons.inbox_outlined, title: 'Nothing here', message: 'No tickets in this stage.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: tickets.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final ticket = tickets[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            title: Text(ticket.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${ticket.customerName} · ${_date.format(ticket.createdAt)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showTicketTriageSheet(context, ref, ticket),
          ),
        );
      },
    );
  }
}
