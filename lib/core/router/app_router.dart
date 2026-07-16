import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_modules.dart';
import '../../features/admin/presentation/admin_routes.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/developer/presentation/developer_home_screen.dart';
import '../../features/guide/presentation/guide_screen.dart';
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
import '../logging/app_logger.dart';

/// Bridges a Riverpod provider to go_router's [Listenable]-based refresh
/// so navigation reacts to role/auth changes without rebuilding the router.
class _RoleRefreshNotifier extends ChangeNotifier {
  _RoleRefreshNotifier(this._ref) {
    _ref.listen<AsyncValue<AppRole?>>(resolvedRoleProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}

AppRole? _roleFor(String path) {
  if (path.startsWith('/customer')) return AppRole.user;
  if (path.startsWith('/staff')) return AppRole.deliveryStaff;
  if (path.startsWith('/manager')) return AppRole.systemManager;
  if (path.startsWith('/admin')) return AppRole.admin;
  if (path.startsWith('/developer')) return AppRole.developer;
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RoleRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) async {
      final path = state.matchedLocation;

      if (path == '/splash') {
        // Anonymous sign-in is disabled project-wide, so there's nothing to
        // bootstrap here anymore — just wait for the real auth state (if
        // any) to resolve to a role.
        final role = await ref.read(resolvedRoleProvider.future);
        appLogger.i('[router] splash resolved role=$role');
        return role == null ? '/login' : role.homePath;
      }

      final role = ref.read(resolvedRoleProvider).valueOrNull;

      if (role == null) {
        return path == '/login' ? null : '/login';
      }

      if (path == '/login') return role.homePath;

      // Developer can freely browse every role's shell — their Firestore
      // permissions already grant it (see hasStaffRole's developer bypass),
      // so there's no path this role needs to be redirected away from.
      if (role == AppRole.developer) return null;

      final requiredRole = _roleFor(path);
      if (requiredRole != null && requiredRole != role) {
        appLogger.w('[router] role=$role blocked from $path (requires $requiredRole) -> redirecting to ${role.homePath}');
        return role.homePath;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/help', builder: (context, state) => const GuideScreen()),
      GoRoute(path: '/developer', builder: (context, state) => const DeveloperHomeScreen()),
      _roleShellRoute(
        role: AppRole.user,
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
        extraRoutes: adminExtraRoutes,
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
          final actualRole = ref.watch(resolvedRoleProvider).valueOrNull;
          final isDeveloperViewing = actualRole == AppRole.developer;

          return AdaptiveRoleShell(
            roleLabel: isDeveloperViewing ? '${role.label} · Developer view' : role.label,
            items: [
              for (final module in modules)
                RoleNavItem(
                  path: module.path,
                  label: module.label,
                  icon: module.icon,
                  selectedIcon: module.selectedIcon,
                  description: module.description,
                ),
            ],
            currentPath: state.matchedLocation,
            onDestinationSelected: (path) => context.go(path),
            onOpenSettings: () => context.push('/settings'),
            onOpenHelp: () => context.push('/help'),
            onSwitchView: isDeveloperViewing
                ? () {
                    appLogger.i('[developer] Switching view back to picker from ${state.matchedLocation}');
                    context.go('/developer');
                  }
                : null,
            onSignOut: () async {
              appLogger.i('[auth] Signing out (role=$actualRole)');
              await ref.read(firebaseAuthProvider).signOut();
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
