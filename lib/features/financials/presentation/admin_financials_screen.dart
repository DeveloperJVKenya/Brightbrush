import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/horizontal_bar_chart.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_status.dart';
import '../application/financials_providers.dart';
import '../domain/expense_model.dart';
import 'widgets/expense_form_sheet.dart';

/// Revenue (from Orders, same computation as Reports/Executive Dashboard)
/// combined with logged Expenses for a simple P&L — Admin/CEO + Developer
/// only, matching Role Management's access tier.
class AdminFinancialsScreen extends ConsumerWidget {
  const AdminFinancialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(allOrdersProvider);
    final expensesAsync = ref.watch(allExpensesProvider);

    if (ordersAsync.isLoading || expensesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (ordersAsync.hasError) {
      appLogger.e('[financials] Failed to load orders', error: ordersAsync.error, stackTrace: ordersAsync.stackTrace);
      return EmptyState(
          icon: Icons.cloud_off_rounded, title: 'Couldn\'t load orders', message: friendlyError(ordersAsync.error!));
    }
    if (expensesAsync.hasError) {
      appLogger.e('[financials] Failed to load expenses', error: expensesAsync.error, stackTrace: expensesAsync.stackTrace);
      return EmptyState(
          icon: Icons.cloud_off_rounded, title: 'Couldn\'t load expenses', message: friendlyError(expensesAsync.error!));
    }

    final orders = ordersAsync.requireValue;
    final expenses = expensesAsync.requireValue;

    final live = orders.where((o) => o.status != OrderStatus.cancelled).toList();
    final collected = live.where((o) => o.paymentStatus.name == 'paid').fold<num>(0, (s, o) => s + o.total);
    final totalExpenses = expenses.fold<num>(0, (s, e) => s + e.amount);
    final net = collected - totalExpenses;

    final byCategory = <ExpenseCategory, num>{};
    for (final e in expenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    final sortedCategories = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final sortedExpenses = [...expenses]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExpenseFormSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Financials', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Revenue collected against logged expenses.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  StatCard(
                    label: 'Collected',
                    value: currencyFormat.format(collected),
                    icon: Icons.account_balance_wallet_outlined,
                    accent: true,
                    hint: 'Revenue actually marked paid, across all non-cancelled orders.',
                  ),
                  StatCard(
                    label: 'Total expenses',
                    value: currencyFormat.format(totalExpenses),
                    icon: Icons.receipt_long_outlined,
                    hint: 'Sum of every logged expense below, all-time.',
                  ),
                  StatCard(
                    label: 'Net',
                    value: currencyFormat.format(net),
                    icon: Icons.trending_up_rounded,
                    hint: 'Collected revenue minus total expenses.',
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (sortedCategories.isNotEmpty) ...[
                Text('Expenses by category', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                HorizontalBarChart(
                  data: [
                    for (final entry in sortedCategories)
                      BarDatum(label: entry.key.label, value: entry.value, valueLabel: currencyFormat.format(entry.value)),
                  ],
                ),
                const SizedBox(height: 28),
              ],
              Text('Expense log', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (sortedExpenses.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No expenses logged yet',
                  message: 'Add materials, utilities, wages and other costs to track the P&L.',
                )
              else
                for (final expense in sortedExpenses) _ExpenseRow(expense: expense),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({required this.expense});

  final ExpenseModel expense;

  static final _date = DateFormat('MMM d, y');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(expense.category.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([_date.format(expense.date), if (expense.note.isNotEmpty) expense.note].join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currencyFormat.format(expense.amount), style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showExpenseFormSheet(context, ref, existing: expense),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete expense?'),
                    content: Text('This ${expense.category.label} expense will be removed permanently.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(expensesRepositoryProvider).delete(expense.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
