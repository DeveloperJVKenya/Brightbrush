import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/brand_mark.dart';

/// Landing page for the Developer role: a "view as" picker into any of the
/// other three role shells. This is purely a navigation affordance — the
/// actual access grant is `hasStaffRole`'s developer bypass in
/// firestore.rules, so browsing into e.g. Admin here doesn't need any
/// separate permission check client-side.
class DeveloperHomeScreen extends ConsumerWidget {
  const DeveloperHomeScreen({super.key});

  static const _viewableRoles = [
    AppRole.user,
    AppRole.deliveryStaff,
    AppRole.systemManager,
    AppRole.admin,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const BrandMark(size: 28),
            const SizedBox(width: 10),
            const Text('Developer'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              appLogger.i('[auth] Developer signing out');
              await ref.read(firebaseAuthProvider).signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('View as', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Your account has full access across every role. Pick a dashboard to browse into it.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  for (final role in _viewableRoles) ...[
                    _ViewAsCard(role: role),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        appLogger.i('[developer] Opening Role Management');
                        context.go('/admin/settings');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.admin_panel_settings_outlined, color: theme.colorScheme.primary),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text('Role Management', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewAsCard extends StatelessWidget {
  const _ViewAsCard({required this.role});

  final AppRole role;

  IconData get _icon => switch (role) {
        AppRole.user => Icons.storefront_outlined,
        AppRole.deliveryStaff => Icons.local_shipping_outlined,
        AppRole.systemManager => Icons.dashboard_outlined,
        AppRole.admin => Icons.insights_outlined,
        AppRole.developer => Icons.code_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          appLogger.i('[developer] Switching view -> ${role.name} (${role.homePath})');
          context.go(role.homePath);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(_icon, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(role.label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
