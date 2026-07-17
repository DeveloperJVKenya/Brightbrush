import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/founding_developer.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/search/search_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_search_field.dart';
import '../../auth/domain/user_profile.dart';

final _roleManagementSearchProvider = StateProvider<String>((ref) => '');

/// Admin/CEO- and Developer-only account directory: view every account and
/// change anyone else's role. firestore.rules is the real gate (see
/// `isAdminOrDeveloper()`) — this screen assumes it's only ever reached by
/// someone that already passes, since the Admin/Developer shells are the
/// only places it's linked from.
class RoleManagementScreen extends ConsumerWidget {
  const RoleManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profilesAsync = ref.watch(allUserProfilesProvider);
    final query = ref.watch(_roleManagementSearchProvider);
    final myUid = ref.watch(currentUidProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Role management', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Every account in the system. Assign or change anyone else\'s role — you can\'t change your own here.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            LiveSearchField(
              hintText: 'Search by name, email, or uid',
              onChanged: (v) => ref.read(_roleManagementSearchProvider.notifier).state = v,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: profilesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) {
                  appLogger.e('[role-mgmt] Failed to load accounts', error: error, stackTrace: stack);
                  return EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Couldn\'t load accounts',
                    message: friendlyError(error),
                  );
                },
                data: (profiles) {
                  final filtered = filterBySearch(
                    profiles,
                    query,
                    (p) => [p.displayName, p.email, p.uid, p.role.label],
                  );
                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: profiles.isEmpty ? 'No accounts yet' : 'No matches',
                      message: profiles.isEmpty ? 'Accounts show up here once someone signs up.' : 'Try a different search term.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final profile = filtered[index];
                      return _AccountRow(profile: profile, isSelf: profile.uid == myUid);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.profile, required this.isSelf});

  final UserProfile profile;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(child: Icon(_iconFor(profile.role))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.displayName.isEmpty ? profile.email : profile.displayName,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('You', style: theme.textTheme.labelSmall),
                        ),
                      ],
                    ],
                  ),
                  Text(profile.email, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  Text(
                    'uid: ${profile.uid}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                profile.role.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!isSelf && profile.uid != foundingDeveloperUid) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Change role',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showRolePicker(context, profile),
              ),
            ] else if (profile.uid == foundingDeveloperUid) ...[
              const SizedBox(width: 4),
              Icon(Icons.lock_outline_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(AppRole role) => switch (role) {
        AppRole.user => Icons.person_outline,
        AppRole.deliveryStaff => Icons.local_shipping_outlined,
        AppRole.systemManager => Icons.dashboard_outlined,
        AppRole.admin => Icons.insights_outlined,
        AppRole.developer => Icons.code_rounded,
      };

  void _showRolePicker(BuildContext context, UserProfile profile) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final myUid = ref.watch(currentUidProvider);
            final canGrantDeveloper = myUid == foundingDeveloperUid;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set role for ${profile.displayName.isEmpty ? profile.email : profile.displayName}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    for (final role in AppRole.values)
                      if (role != AppRole.developer || canGrantDeveloper)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          role == profile.role ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: role == profile.role ? Theme.of(context).colorScheme.primary : null,
                        ),
                        title: Text(role.label),
                        onTap: () async {
                          Navigator.of(context).pop();
                          if (role == profile.role) return;
                          final myUid = ref.read(currentUidProvider);
                          try {
                            appLogger.i('[role-mgmt] Setting ${profile.uid} -> ${role.name}');
                            await ref.read(userProfileRepositoryProvider).updateRole(
                                  uid: profile.uid,
                                  role: role,
                                  changedByUid: myUid ?? 'unknown',
                                );
                          } catch (error, stack) {
                            appLogger.e('[role-mgmt] Failed to set role for ${profile.uid}', error: error, stackTrace: stack);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Couldn\'t change role: ${friendlyError(error)}'),
                                    behavior: SnackBarBehavior.floating),
                              );
                            }
                          }
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
