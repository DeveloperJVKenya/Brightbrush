import 'package:go_router/go_router.dart';

import '../../quotes/presentation/my_quotes_screen.dart';
import 'catalog_item_detail_screen.dart';
import 'order_detail_screen.dart';

/// Nested routes reached from within a module rather than the nav rail
/// itself (e.g. tapping a catalog card), so they stay inside the same
/// shell/chrome as the Home module.
final List<RouteBase> customerExtraRoutes = [
  GoRoute(
    path: '/customer/quotes',
    builder: (context, state) => const MyQuotesScreen(),
  ),
  GoRoute(
    path: '/customer/catalog/:id',
    builder: (context, state) =>
        CatalogItemDetailScreen(itemId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/customer/orders/:id',
    builder: (context, state) =>
        OrderDetailScreen(
          orderId: state.pathParameters['id']!,
          paymentOutcome: state.uri.queryParameters['payment'],
        ),
  ),
];
