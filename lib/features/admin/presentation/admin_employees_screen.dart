import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../auth/domain/user_profile.dart';
import '../../financials/application/financials_providers.dart';
import '../../financials/domain/expense_model.dart';

/// Derived entirely from the existing Users directory — no separate
/// payroll/schedule data model exists yet, so this sticks to what's real:
/// who holds which staff role, with a link into Role Management for edits,
/// plus a daily wage rate per manual worker and a one-tap way to log that
/// day's pay as a real Expense.
class AdminEmployeesScreen extends ConsumerWidget {
  const AdminEmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profilesAsync = ref.watch(allUserProfilesProvider);

    return SafeArea(
      child: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load employees', message: '$error'),
        data: (profiles) {
          final staff = profiles.where((p) => p.role != AppRole.user).toList()
            ..sort((a, b) => a.role.index.compareTo(b.role.index));
          final byRole = <AppRole, List<UserProfile>>{};
          for (final p in staff) {
            (byRole[p.role] ??= []).add(p);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Employees', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            'Every staff account, by role. Roles are assigned in Role Management.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/admin/settings'),
                      icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                      label: const Text('Role Management'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final role in [AppRole.systemManager, AppRole.admin, AppRole.deliveryStaff, AppRole.developer])
                      StatCard(label: role.label, value: '${byRole[role]?.length ?? 0}', icon: Icons.badge_outlined),
                  ],
                ),
                const SizedBox(height: 24),
                if (staff.isEmpty)
                  const EmptyState(
                    icon: Icons.badge_outlined,
                    title: 'No staff accounts yet',
                    message: 'Assign a role to an account from Role Management to see it here.',
                  )
                else
                  for (final role in byRole.keys) ...[
                    Text(role.label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    for (final person in byRole[role]!) _EmployeeRow(person: person),
                    const SizedBox(height: 16),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmployeeRow extends ConsumerStatefulWidget {
  const _EmployeeRow({required this.person});

  final UserProfile person;

  @override
  ConsumerState<_EmployeeRow> createState() => _EmployeeRowState();
}

class _EmployeeRowState extends ConsumerState<_EmployeeRow> {
  bool _loggingPay = false;

  Future<void> _editWage() async {
    final controller = TextEditingController(text: widget.person.dailyWage?.toString() ?? '');
    final result = await showDialog<num>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Daily wage — ${widget.person.displayName}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (KES per day)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(num.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await ref.read(userProfileRepositoryProvider).updateDailyWage(uid: widget.person.uid, dailyWage: result);
    } catch (error) {
      appLogger.e('[employees] Failed to update dailyWage for ${widget.person.uid}', error: error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t save: $error'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _logTodaysPay() async {
    final wage = widget.person.dailyWage;
    if (wage == null || wage <= 0) return;
    setState(() => _loggingPay = true);
    try {
      final uid = ref.read(currentUidProvider);
      await ref.read(expensesRepositoryProvider).create(
            ExpenseModel(
              id: '',
              category: ExpenseCategory.wages,
              amount: wage,
              note: 'Daily wage — ${widget.person.displayName.isEmpty ? widget.person.email : widget.person.displayName}',
              date: DateTime.now(),
              createdBy: uid ?? '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            uid: uid ?? '',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged in Financials'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (error) {
      appLogger.e('[employees] Failed to log daily pay for ${widget.person.uid}', error: error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t log pay: $error'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingPay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wage = widget.person.dailyWage;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(widget.person.displayName.isNotEmpty ? widget.person.displayName[0].toUpperCase() : '?'),
        ),
        title: Text(widget.person.displayName.isEmpty ? widget.person.email : widget.person.displayName),
        subtitle: Text(wage == null || wage <= 0 ? '${widget.person.email} · No daily wage set' : '${widget.person.email} · ${currencyFormat.format(wage)}/day'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (wage != null && wage > 0)
              _loggingPay
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      tooltip: 'Log today\'s pay',
                      icon: const Icon(Icons.payments_outlined),
                      onPressed: _logTodaysPay,
                      color: theme.colorScheme.primary,
                    ),
            IconButton(
              tooltip: 'Set daily wage',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editWage,
            ),
          ],
        ),
      ),
    );
  }
}
