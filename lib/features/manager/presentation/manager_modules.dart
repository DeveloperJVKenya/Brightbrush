import 'package:flutter/material.dart';

import '../../../shared/widgets/module_spec.dart';
import 'manager_catalog_screen.dart';
import 'manager_orders_screen.dart';
import 'manager_packages_screen.dart';

/// Sections available to the System Manager: keeper of the public catalog,
/// packages, orders pipeline and service history.
///
/// Not `const`: modules with a real [ModuleSpec.screenBuilder] hold a
/// closure, which isn't a compile-time constant.
final List<ModuleSpec> managerModules = [
  const ModuleSpec(
    path: '/manager',
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    description: 'Snapshot of today\'s new orders, production load, and low-stock alerts.',
  ),
  ModuleSpec(
    path: '/manager/catalog',
    label: 'Catalog',
    icon: Icons.checkroom_outlined,
    selectedIcon: Icons.checkroom,
    description:
        'Manage branding items and branding forms shown to customers (caps, T-shirts, hoodies, '
        'two-piece sets, water bottles, cutlery, embroidery and more), pricing and MOQs.',
    screenBuilder: (context, state) => const ManagerCatalogScreen(),
  ),
  ModuleSpec(
    path: '/manager/packages',
    label: 'Packages',
    icon: Icons.card_giftcard_outlined,
    selectedIcon: Icons.card_giftcard,
    description: 'Create and schedule seasonal/campaign bundles (Valentine\'s, elections, etc).',
    screenBuilder: (context, state) => const ManagerPackagesScreen(),
  ),
  ModuleSpec(
    path: '/manager/orders',
    label: 'Orders',
    icon: Icons.list_alt_outlined,
    selectedIcon: Icons.list_alt,
    description: 'Incoming, in-production and completed orders across all clients.',
    screenBuilder: (context, state) => const ManagerOrdersScreen(),
  ),
  const ModuleSpec(
    path: '/manager/history',
    label: 'Service History',
    icon: Icons.fact_check_outlined,
    selectedIcon: Icons.fact_check,
    description: 'Archive of completed jobs for reference, reprints and client history lookups.',
  ),
  const ModuleSpec(
    path: '/manager/inventory',
    label: 'Inventory',
    icon: Icons.inventory_outlined,
    selectedIcon: Icons.inventory,
    description: 'Paint, blanks, thread and other materials — stock levels and reorder points.',
  ),
  const ModuleSpec(
    path: '/manager/staff',
    label: 'Staff Assignment',
    icon: Icons.groups_2_outlined,
    selectedIcon: Icons.groups_2,
    description: 'Assign production and delivery staff to orders and routes.',
  ),
  const ModuleSpec(
    path: '/manager/profile',
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    description: 'Your account and notification preferences.',
  ),
];
