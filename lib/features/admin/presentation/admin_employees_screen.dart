import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../auth/domain/user_profile.dart';

/// Derived entirely from the existing Users directory — no separate
/// payroll/schedule data model exists yet, so this sticks to what's real:
/// who holds which staff role, with a link into Role Management for edits.
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
                    for (final person in byRole[role]!)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(child: Text(person.displayName.isNotEmpty ? person.displayName[0].toUpperCase() : '?')),
                          title: Text(person.displayName.isEmpty ? person.email : person.displayName),
                          subtitle: Text(person.email),
                        ),
                      ),
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
