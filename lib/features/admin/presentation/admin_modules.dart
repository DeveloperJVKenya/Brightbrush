import 'package:flutter/material.dart';

import '../../../shared/widgets/module_spec.dart';
import '../../assets/presentation/admin_assets_screen.dart';
import '../../financials/presentation/admin_financials_screen.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../marketing/presentation/admin_marketing_screen.dart';
import 'admin_deliveries_screen.dart';
import 'admin_employees_screen.dart';
import 'admin_executive_dashboard_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_reports_screen.dart';
import 'role_management_screen.dart';

/// Sections available to the Admin/CEO: full financial and operational
/// oversight across the whole company.
///
/// Not `const`: modules with a real [ModuleSpec.screenBuilder] hold a
/// closure, which isn't a compile-time constant.
final List<ModuleSpec> adminModules = [
  ModuleSpec(
    path: '/admin',
    label: 'Executive Dashboard',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    description: 'Revenue and order pipeline at a glance, with completed, running and upcoming orders.',
    screenBuilder: (context, state) => const AdminExecutiveDashboardScreen(),
  ),
  ModuleSpec(
    path: '/admin/financials',
    label: 'Financials',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    description: 'Revenue collected against logged expenses — materials, utilities, wages, delivery and misc.',
    screenBuilder: (context, state) => const AdminFinancialsScreen(),
  ),
  ModuleSpec(
    path: '/admin/orders',
    label: 'Orders Overview',
    icon: Icons.list_alt_outlined,
    selectedIcon: Icons.list_alt,
    description: 'All company orders — completed, running, and upcoming — across every client.',
    screenBuilder: (context, state) => const AdminOrdersScreen(),
  ),
  ModuleSpec(
    path: '/admin/deliveries',
    label: 'Deliveries',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping,
    description: 'Delivery notices, delivery plans, and live fleet tracking on the map.',
    screenBuilder: (context, state) => const AdminDeliveriesScreen(),
  ),
  ModuleSpec(
    path: '/admin/employees',
    label: 'Employees',
    icon: Icons.badge_outlined,
    selectedIcon: Icons.badge,
    description: 'Every staff account by role, linking to Role Management for changes.',
    screenBuilder: (context, state) => const AdminEmployeesScreen(),
  ),
  ModuleSpec(
    path: '/admin/assets',
    label: 'Company Assets',
    icon: Icons.precision_manufacturing_outlined,
    selectedIcon: Icons.precision_manufacturing,
    description: 'In-house machines and equipment used across the branding process.',
    screenBuilder: (context, state) => const AdminAssetsScreen(),
  ),
  ModuleSpec(
    path: '/admin/inventory',
    label: 'Inventory & Suppliers',
    icon: Icons.inventory_outlined,
    selectedIcon: Icons.inventory,
    description: 'Materials (paint, blanks, thread) and supplier relationships.',
    screenBuilder: (context, state) => const InventoryScreen(),
  ),
  ModuleSpec(
    path: '/admin/marketing',
    label: 'Marketing',
    icon: Icons.campaign_outlined,
    selectedIcon: Icons.campaign,
    description: 'Announcements and seasonal promotions shown on every customer\'s Home.',
    screenBuilder: (context, state) => const AdminMarketingScreen(),
  ),
  ModuleSpec(
    path: '/admin/reports',
    label: 'Reports',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
    description: 'Analytics across sales, production and delivery, with a copyable summary.',
    screenBuilder: (context, state) => const AdminReportsScreen(),
  ),
  ModuleSpec(
    path: '/admin/settings',
    label: 'Role Management',
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings,
    description: 'Every account in the system — assign or change anyone\'s role.',
    screenBuilder: (context, state) => const RoleManagementScreen(),
  ),
];
