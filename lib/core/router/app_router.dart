import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_modules.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/manager/presentation/manager_modules.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/staff/presentation/staff_modules.dart';
import '../../features/customer/presentation/customer_modules.dart';
import '../../features/customer/presentation/customer_routes.dart';
import '../../shared/widgets/adaptive_role_shell.dart';
import '../../shared/widgets/module_spec.dart';
import '../../shared/widgets/placeholder_screen.dart';
import '../../shared/widgets/role_nav_item.dart';
import '../auth/app_role.dart';
import '../auth/auth_providers.dart';
import '../firebase/firebase_providers.dart';

/// Bridges a Riverpod provider to go_router's [Listenable]-based refresh
/// so navigation reacts to role/auth changes without rebuilding the router.
class _RoleRefreshNotifier extends ChangeNotifier {
  _RoleRefreshNotifier(this._ref) {
    _ref.listen<AppRole?>(currentRoleProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RoleRefreshNotifier(ref);

  AppRole? roleFor(String path) {
    if (path.startsWith('/customer')) return AppRole.customer;
    if (path.startsWith('/staff')) return AppRole.deliveryStaff;
    if (path.startsWith('/manager')) return AppRole.systemManager;
    if (path.startsWith('/admin')) return AppRole.admin;
    return null;
  }

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) async {
      final role = ref.read(currentRoleProvider);
      final path = state.matchedLocation;

      if (path == '/splash') {
        // Firestore/Storage rules require request.auth != null, so every
        // visitor is signed in anonymously before anything else loads.
        await ref.read(ensureSignedInProvider.future);
        return role == null ? '/login' : role.homePath;
      }

      if (role == null) {
        return path == '/login' ? null : '/login';
      }

      if (path == '/login') return role.homePath;

      final requiredRole = roleFor(path);
      if (requiredRole != null && requiredRole != role) {
        return role.homePath;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      _roleShellRoute(
        role: AppRole.customer,
        modules: customerModules,
        extraRoutes: customerExtraRoutes,
      ),
      _roleShellRoute(
        role: AppRole.deliveryStaff,
        modules: staffModules,
      ),
      _roleShellRoute(
        role: AppRole.systemManager,
        modules: managerModules,
      ),
      _roleShellRoute(
        role: AppRole.admin,
        modules: adminModules,
      ),
    ],
  );
});

/// Builds a top-level [ShellRoute] for one role: a persistent
/// [AdaptiveRoleShell] wrapping a flat set of module routes (real screen if
/// [ModuleSpec.screenBuilder] is set, placeholder otherwise), plus any
/// [extraRoutes] nested underneath (e.g. an item detail page reached from
/// within a module rather than the nav rail itself).
ShellRoute _roleShellRoute({
  required AppRole role,
  required List<ModuleSpec> modules,
  List<RouteBase> extraRoutes = const [],
}) {
  return ShellRoute(
    builder: (context, state, child) {
      return Consumer(
        builder: (context, ref, _) {
          return AdaptiveRoleShell(
            roleLabel: role.label,
            items: [
              for (final module in modules)
                RoleNavItem(
                  path: module.path,
                  label: module.label,
                  icon: module.icon,
                  selectedIcon: module.selectedIcon,
                ),
            ],
            currentPath: state.matchedLocation,
            onDestinationSelected: (path) => context.go(path),
            onOpenSettings: () => context.push('/settings'),
            onSwitchRole: () {
              ref.read(currentRoleProvider.notifier).state = null;
              context.go('/login');
            },
            child: child,
          );
        },
      );
    },
    routes: [
      for (final module in modules)
        GoRoute(
          path: module.path,
          builder: module.screenBuilder ??
              (context, state) => PlaceholderScreen(
                    title: module.label,
                    description: module.description,
                    icon: module.icon,
                  ),
        ),
      ...extraRoutes,
    ],
  );
}
