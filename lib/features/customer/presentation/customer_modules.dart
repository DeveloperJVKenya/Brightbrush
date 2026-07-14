import 'package:flutter/material.dart';

import '../../../shared/widgets/module_spec.dart';
import 'cart_checkout_screen.dart';
import 'customer_catalog_screen.dart';
import 'my_orders_screen.dart';
import 'packages_screen.dart';

/// Sections available to a Customer/Client. Order matters: the first
/// entries fill the mobile bottom bar, the rest fold into the drawer.
///
/// Not `const`: modules with a real [ModuleSpec.screenBuilder] hold a
/// closure, which isn't a compile-time constant.
final List<ModuleSpec> customerModules = [
  ModuleSpec(
    path: '/customer',
    label: 'Home',
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront,
    description:
        'Browse branding items — caps, T-shirts, hoodies, two-piece sets, water bottles, '
        'cutlery, embroidery and other branding forms — with pricing, MOQ and lead times.',
    screenBuilder: (context, state) => const CustomerCatalogScreen(),
  ),
  ModuleSpec(
    path: '/customer/packages',
    label: 'Packages',
    icon: Icons.card_giftcard_outlined,
    selectedIcon: Icons.card_giftcard,
    description:
        'Seasonal & campaign branding bundles (e.g. Valentine\'s, election-campaign packs) '
        'curated by the System Manager.',
    screenBuilder: (context, state) => const PackagesScreen(),
  ),
  ModuleSpec(
    path: '/customer/orders',
    label: 'My Orders',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    description:
        'Place new bulk or personal orders, and follow each order through design approval, '
        'production and delivery.',
    screenBuilder: (context, state) => const MyOrdersScreen(),
  ),
  const ModuleSpec(
    path: '/customer/tracking',
    label: 'Track Delivery',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping,
    description:
        'Live map view of your delivery once it is out, powered by the in-app Google Maps '
        'tracking integration.',
  ),
  ModuleSpec(
    path: '/customer/cart',
    label: 'Cart & Checkout',
    icon: Icons.shopping_cart_outlined,
    selectedIcon: Icons.shopping_cart,
    description: 'Review items, choose quantities and confirm your order.',
    screenBuilder: (context, state) => const CartCheckoutScreen(),
  ),
  const ModuleSpec(
    path: '/customer/notifications',
    label: 'Notifications',
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
    description: 'Order status changes, delivery updates and seasonal offers.',
  ),
  const ModuleSpec(
    path: '/customer/support',
    label: 'Support',
    icon: Icons.support_agent_outlined,
    selectedIcon: Icons.support_agent,
    description: 'Chat with BrightBrush about an order, a design, or a complaint.',
  ),
  const ModuleSpec(
    path: '/customer/profile',
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    description: 'Account details, saved addresses, and order history.',
  ),
];
