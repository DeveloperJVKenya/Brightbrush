import 'package:go_router/go_router.dart';

import '../../support/presentation/admin_support_inbox_screen.dart';

/// Reached via a quick-link from the Executive Dashboard rather than the nav
/// rail itself, same reasoning as [customerExtraRoutes] for detail pages —
/// this keeps the persistent nav exactly as designed while still giving
/// Support tickets a real place to be triaged.
final List<RouteBase> adminExtraRoutes = [
  GoRoute(
    path: '/admin/support',
    builder: (context, state) => const AdminSupportInboxScreen(),
  ),
];
