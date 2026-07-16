import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../application/support_providers.dart';
import '../../domain/support_ticket.dart';

Future<void> showTicketTriageSheet(BuildContext context, WidgetRef ref, SupportTicket ticket) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _TicketTriageSheet(ticket: ticket),
  );
}

class _TicketTriageSheet extends ConsumerStatefulWidget {
  const _TicketTriageSheet({required this.ticket});

  final SupportTicket ticket;

  @override
  ConsumerState<_TicketTriageSheet> createState() => _TicketTriageSheetState();
}

class _TicketTriageSheetState extends ConsumerState<_TicketTriageSheet> {
  late final _response = TextEditingController(text: widget.ticket.response ?? '');
  late TicketStatus _status = widget.ticket.status;
  bool _saving = false;

  @override
  void dispose() {
    _response.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(supportTicketsRepositoryProvider).triage(SupportTicket(
            id: widget.ticket.id,
            subject: widget.ticket.subject,
            message: widget.ticket.message,
            customerId: widget.ticket.customerId,
            customerName: widget.ticket.customerName,
            status: _status,
            response: _response.text.trim(),
            createdAt: widget.ticket.createdAt,
            updatedAt: DateTime.now(),
          ));
      appLogger.i('[support] Triaged ticket ${widget.ticket.id} -> ${_status.name}');
      if (mounted) Navigator.of(context).pop();
    } catch (error, stack) {
      appLogger.e('[support] Failed to triage ticket ${widget.ticket.id}', error: error, stackTrace: stack);
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
      padding: EdgeInsets.only(left: 20, right: 20, top: 4, bottom: MediaQuery.viewInsetsOf(context).bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.ticket.subject, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('From ${widget.ticket.customerName}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
              width: double.infinity,
              child: Text(widget.ticket.message),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TicketStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [for (final s in TicketStatus.values) DropdownMenuItem(value: s, child: Text(s.label))],
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _response,
              decoration: const InputDecoration(labelText: 'Response to customer'),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
