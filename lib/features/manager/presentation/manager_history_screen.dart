import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/search/search_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_search_field.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/domain/order_status.dart';

final _historySearchProvider = StateProvider<String>((ref) => '');

/// Archive of completed and cancelled jobs — reference for reprints and
/// client history lookups. Read-only: status changes happen from the
/// Orders screen while a job is still in flight.
class ManagerHistoryScreen extends ConsumerWidget {
  const ManagerHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(allOrdersProvider);
    final query = ref.watch(_historySearchProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service history',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Completed and cancelled jobs, for reference and reprints.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => const OrderArchiveScreen(),
                  ),
                ),
                icon: const Icon(Icons.manage_search_rounded),
                label: const Text(
                  'Older than ${OrdersRepository.recentDays} days? Search the full archive',
                ),
              ),
            ),
            const SizedBox(height: 8),
            LiveSearchField(
              hintText: 'Search by customer, phone, order id, or item',
              onChanged: (v) =>
                  ref.read(_historySearchProvider.notifier).state = v,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(semanticsLabel: 'Loading'),
                ),
                error: (error, stack) {
                  appLogger.e(
                    '[history] Failed to load service history',
                    error: error,
                    stackTrace: stack,
                  );
                  return EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Couldn\'t load history',
                    message: friendlyError(error),
                    action: TextButton.icon(
                      onPressed: () => ref.invalidate(allOrdersProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  );
                },
                data: (orders) {
                  final done =
                      orders
                          .where(
                            (o) =>
                                o.status == OrderStatus.completed ||
                                o.status == OrderStatus.cancelled,
                          )
                          .toList()
                        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                  final filtered = filterBySearch(
                    done,
                    query,
                    (o) => o.searchFields,
                  );
                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.fact_check_outlined,
                      title: done.isEmpty
                          ? 'Nothing archived yet'
                          : 'No matches',
                      message: done.isEmpty
                          ? 'Completed and cancelled orders will show up here.'
                          : 'Try a different search term.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _HistoryRow(order: filtered[index]),
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.order});

  final OrderModel order;

  static final _date = DateFormat('MMM d, y · h:mm a');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = order.status == OrderStatus.completed;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          completed
              ? Icons.check_circle_outline_rounded
              : Icons.cancel_outlined,
          color: completed
              ? theme.colorScheme.primary
              : theme.colorScheme.error,
        ),
        title: Text(
          order.contactName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${order.items.map((i) => '${i.quantity}× ${i.name}').join(', ')}\n${_date.format(order.updatedAt)}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              currencyFormat.format(order.total),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(order.status.label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Every order ever placed, searchable by order/invoice number, customer
/// name, company, phone or email, loaded 30 at a time. The live lists
/// only hold the recent working set, so this is where old jobs are found.
class OrderArchiveScreen extends ConsumerStatefulWidget {
  const OrderArchiveScreen({super.key});

  @override
  ConsumerState<OrderArchiveScreen> createState() => _OrderArchiveScreenState();
}

class _OrderArchiveScreenState extends ConsumerState<OrderArchiveScreen> {
  final _orders = <OrderModel>[];
  DocumentSnapshot<Map<String, dynamic>>? _next;
  String _query = '';
  bool _loading = false;
  bool _done = false;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final gen = reset ? ++_generation : _generation;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _orders.clear();
        _next = null;
        _done = false;
      }
    });
    try {
      final page = await ref
          .read(ordersRepositoryProvider)
          .searchArchive(query: _query, after: _next);
      if (!mounted || gen != _generation) return;
      setState(() {
        _orders.addAll(page.orders);
        _next = page.next;
        _done = page.next == null;
      });
    } catch (error, stack) {
      appLogger.e('[archive] search failed', error: error, stackTrace: stack);
      if (mounted && gen == _generation) setState(() => _error = error);
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order archive')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              LiveSearchField(
                hintText: 'Order number, customer, company, phone or email',
                onChanged: (v) {
                  if (archiveSearchKey(v) == archiveSearchKey(_query)) return;
                  _query = v;
                  _load(reset: true);
                },
              ),
              const SizedBox(height: 12),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null && _orders.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't search the archive",
        message: friendlyError(_error!),
        action: TextButton.icon(
          onPressed: () => _load(reset: true),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      );
    }
    if (_orders.isEmpty) {
      return _loading
          ? const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Loading'),
            )
          : const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No orders found',
              message: 'Try an order number, a surname or a phone number.',
            );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _orders.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index < _orders.length) return _HistoryRow(order: _orders[index]);
        if (_done) return const SizedBox(height: 8);
        return Center(
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(semanticsLabel: 'Loading'),
                )
              : OutlinedButton(
                  onPressed: _load,
                  child: const Text('Load more'),
                ),
        );
      },
    );
  }
}
