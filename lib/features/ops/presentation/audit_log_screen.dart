import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../shared/widgets/empty_state.dart';
import '../application/ops_providers.dart';

/// Admin/CEO: who changed what — prices, roles, payments, refunds,
/// settings, gateways, business accounts, promo codes and order moves.
/// Entries are written by the server and can't be edited or deleted.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _query = '';
  String _entity = 'all';

  static const _entities = {
    'all': 'Everything',
    'order': 'Orders & payments',
    'user': 'Staff & roles',
    'catalog': 'Catalog & prices',
    'settings': 'Settings',
    'gateway': 'Payment gateways',
    'account': 'Business accounts',
    'coupon': 'Promo codes',
  };

  static IconData _icon(String type) => switch (type.split('.').first) {
    'order' || 'payment' || 'refund' => Icons.receipt_long_outlined,
    'user' => Icons.admin_panel_settings_outlined,
    'catalog' => Icons.sell_outlined,
    'settings' => Icons.settings_outlined,
    'gateway' => Icons.point_of_sale_outlined,
    'account' => Icons.business_outlined,
    'coupon' => Icons.local_offer_outlined,
    _ => Icons.history_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(auditLogProvider);
    final names = {
      for (final p
          in ref.watch(allUserProfilesProvider).valueOrNull ?? const [])
        p.uid: p.displayName,
    };
    final fmt = DateFormat('d MMM y, HH:mm');
    String who(String actor) => actor.startsWith('system')
        ? 'Automatic (${actor.replaceFirst('system:', '')})'
        : names[actor] ?? (actor == 'unknown' ? 'Unknown' : actor);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn\'t load the audit log',
        message: friendlyError(e),
      ),
      data: (entries) {
        final shown = entries.where((e) {
          if (_entity != 'all' &&
              !e.type.startsWith('$_entity.') &&
              !(_entity == 'order' &&
                  (e.type.startsWith('payment.') ||
                      e.type.startsWith('refund.')))) {
            return false;
          }
          final q = _query.toLowerCase();
          return q.isEmpty ||
              e.summary.toLowerCase().contains(q) ||
              who(e.actor).toLowerCase().contains(q);
        }).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Audit log',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'The latest 300 changes. Entries are written automatically and cannot be edited.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search by order, item, person…',
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in _entities.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _entity == e.key,
                    onSelected: (_) => setState(() => _entity = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (shown.isEmpty)
              const EmptyState(
                icon: Icons.history_rounded,
                title: 'Nothing here yet',
                message: 'Changes appear as they happen.',
              ),
            for (final e in shown)
              Card(
                child: ExpansionTile(
                  leading: Icon(_icon(e.type)),
                  title: Text(e.summary),
                  subtitle: Text('${who(e.actor)} · ${fmt.format(e.at)}'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    for (final c in e.changes.entries)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${c.key}: ${(c.value as Map)['from'] ?? '—'} → ${(c.value as Map)['to'] ?? '—'}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
