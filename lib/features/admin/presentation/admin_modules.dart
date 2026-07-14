import 'package:flutter/material.dart';

import '../../../shared/widgets/module_spec.dart';
import 'admin_orders_screen.dart';

/// Sections available to the Admin/CEO: full financial and operational
/// oversight across the whole company.
///
/// Not `const`: modules with a real [ModuleSpec.screenBuilder] hold a
/// closure, which isn't a compile-time constant.
final List<ModuleSpec> adminModules = [
  const ModuleSpec(
    path: '/admin',
    label: 'Executive Dashboard',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    description:
        'Revenue, expenses, profit/loss and order pipeline at a glance, with completed, '
        'running and upcoming orders.',
  ),
  const ModuleSpec(
    path: '/admin/financials',
    label: 'Financials',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    description:
        'Revenue, bills, order-related expenses, deliveries, employee payments and '
        'miscellaneous payments — with profit & loss reporting.',
  ),
  ModuleSpec(
    path: '/admin/orders',
    label: 'Orders Overview',
    icon: Icons.list_alt_outlined,
    selectedIcon: Icons.list_alt,
    description: 'All company orders — completed, running, and upcoming — across every client.',
    screenBuilder: (context, state) => const AdminOrdersScreen(),
  ),
  const ModuleSpec(
    path: '/admin/deliveries',
    label: 'Deliveries',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping,
    description: 'Delivery notices, delivery plans, and live fleet tracking on the map.',
  ),
  const ModuleSpec(
    path: '/admin/employees',
    label: 'Employees',
    icon: Icons.badge_outlined,
    selectedIcon: Icons.badge,
    description: 'Staff records, roles, schedules and payroll.',
  ),
  const ModuleSpec(
    path: '/admin/assets',
    label: 'Company Assets',
    icon: Icons.precision_manufacturing_outlined,
    selectedIcon: Icons.precision_manufacturing,
    description: 'In-house machines and equipment used across the branding process.',
  ),
  const ModuleSpec(
    path: '/admin/inventory',
    label: 'Inventory & Suppliers',
    icon: Icons.inventory_outlined,
    selectedIcon: Icons.inventory,
    description: 'Materials (paint, blanks, thread) and supplier relationships.',
  ),
  const ModuleSpec(
    path: '/admin/marketing',
    label: 'Marketing',
    icon: Icons.campaign_outlined,
    selectedIcon: Icons.campaign,
    description: 'Online brand presence, seasonal campaigns and promotions.',
  ),
  const ModuleSpec(
    path: '/admin/reports',
    label: 'Reports',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
    description: 'Analytics and exportable reports across sales, production and delivery.',
  ),
  const ModuleSpec(
    path: '/admin/settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    description: 'Company profile, user & role management, and system configuration.',
  ),
];
