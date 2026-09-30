import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/formatting/currency.dart';
import '../../core/logging/stream_error_logger.dart';
import '../../shared/widgets/stat_card.dart';

/// Counters kept by the aggregateOrderStats function (Stats/totals and
/// Stats/daily-yyyy-MM-dd), so all-time numbers don't need every order
/// loaded on the device.
class OrderStats {
  const OrderStats(this.values, {this.rebuiltAt});

  final Map<String, num> values;
  final DateTime? rebuiltAt;

  num operator [](String key) => values[key] ?? 0;

  static OrderStats fromMap(Map<String, dynamic>? d) => OrderStats({
    for (final e in (d ?? const {}).entries)
      if (e.value is num) e.key: e.value as num,
  }, rebuiltAt: (d?['rebuiltAt'] as Timestamp?)?.toDate());
}

/// yyyy-MM-dd in Nairobi time (the server's day boundary).
String nairobiDay(DateTime t) =>
    DateFormat('yyyy-MM-dd').format(t.toUtc().add(const Duration(hours: 3)));

final orderStatsTotalsProvider = StreamProvider<OrderStats>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('Stats')
      .doc('totals')
      .snapshots()
      .map((s) => OrderStats.fromMap(s.data()))
      .transform(logStreamErrors('[stats] totals failed'));
});

/// The last [days] daily documents, oldest first (missing days are zero).
final orderStatsDailyProvider =
    StreamProvider.family<List<(String, OrderStats)>, int>((ref, days) {
      final now = DateTime.now();
      final keys = [
        for (var i = days - 1; i >= 0; i--)
          nairobiDay(now.subtract(Duration(days: i))),
      ];
      return ref
          .watch(firestoreProvider)
          .collection('Stats')
          .where('day', isGreaterThanOrEqualTo: keys.first)
          .snapshots()
          .map((snap) {
            final byDay = {
              for (final d in snap.docs)
                d.data()['day'] as String: OrderStats.fromMap(d.data()),
            };
            return [
              for (final k in keys) (k, byDay[k] ?? const OrderStats({})),
            ];
          })
          .transform(logStreamErrors('[stats] daily failed'));
    });

/// "All time" and "Last 30 days" cards for the dashboards, plus a recount
/// button for admins.
class AllTimeStatsSection extends ConsumerWidget {
  const AllTimeStatsSection({super.key, this.canRecount = false});

  final bool canRecount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final totals = ref.watch(orderStatsTotalsProvider).valueOrNull;
    final month = ref.watch(orderStatsDailyProvider(30)).valueOrNull;
    if (totals == null) return const SizedBox.shrink();
    num sum(String k) =>
        (month ?? const []).fold<num>(0, (t, d) => t + d.$2[k]);
    final today = month?.isNotEmpty == true ? month!.last.$2 : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'All time',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (canRecount) _RecountButton(rebuiltAt: totals.rebuiltAt),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            StatCard(
              label: 'Orders placed',
              value: '${totals['ordersPlaced']}',
              icon: Icons.shopping_bag_outlined,
            ),
            StatCard(
              label: 'Order value',
              value: currencyFormat.format(totals['orderValue']),
              icon: Icons.receipt_long_outlined,
            ),
            StatCard(
              label: 'Collected',
              value: currencyFormat.format(
                totals['collected'] - totals['refunded'],
              ),
              icon: Icons.account_balance_wallet_outlined,
              accent: true,
              hint: 'Payments received minus refunds, since the start.',
            ),
            StatCard(
              label: 'Completed',
              value: '${totals['ordersCompleted']}',
              icon: Icons.check_circle_outline_rounded,
            ),
          ],
        ),
        if (month != null) ...[
          const SizedBox(height: 20),
          Text(
            'Last 30 days',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatCard(
                label: 'Orders placed',
                value: '${sum('ordersPlaced')}',
                icon: Icons.shopping_bag_outlined,
                hint: 'Today: ${today?['ordersPlaced'] ?? 0}',
              ),
              StatCard(
                label: 'Collected',
                value: currencyFormat.format(
                  sum('collected') - sum('refunded'),
                ),
                icon: Icons.payments_outlined,
                accent: true,
                hint:
                    'Today: ${currencyFormat.format((today?['collected'] ?? 0) - (today?['refunded'] ?? 0))}',
              ),
              StatCard(
                label: 'Completed',
                value: '${sum('ordersCompleted')}',
                icon: Icons.check_circle_outline_rounded,
              ),
              StatCard(
                label: 'Cancelled',
                value: '${sum('ordersCancelled')}',
                icon: Icons.cancel_outlined,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RecountButton extends ConsumerStatefulWidget {
  const _RecountButton({this.rebuiltAt});

  final DateTime? rebuiltAt;

  @override
  ConsumerState<_RecountButton> createState() => _RecountButtonState();
}

class _RecountButtonState extends ConsumerState<_RecountButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('rebuildOrderStats')
          .call<Map<String, dynamic>>();
      messenger.showSnackBar(
        SnackBar(content: Text('Recounted ${r.data['orders']} orders.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.rebuiltAt == null
          ? 'Count every order placed so far (run once after setup)'
          : 'Last recounted ${DateFormat('d MMM y').format(widget.rebuiltAt!)}',
      child: TextButton.icon(
        onPressed: _busy ? null : _run,
        icon: _busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.calculate_outlined),
        label: const Text('Recount'),
      ),
    );
  }
}
