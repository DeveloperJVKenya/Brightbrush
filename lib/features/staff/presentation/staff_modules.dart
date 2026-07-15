import 'package:flutter/material.dart';

import '../../../shared/widgets/module_spec.dart';
import 'delivery_history_screen.dart';
import 'my_deliveries_screen.dart';
import 'route_map_screen.dart';

/// Sections available to Delivery Staff.
///
/// Not `const`: modules with a real [ModuleSpec.screenBuilder] hold a
/// closure, which isn't a compile-time constant.
final List<ModuleSpec> staffModules = [
  ModuleSpec(
    path: '/staff',
    label: 'My Deliveries',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
    description: 'Deliveries assigned to you today, grouped by route and priority.',
    screenBuilder: (context, state) => const MyDeliveriesScreen(),
  ),
  ModuleSpec(
    path: '/staff/map',
    label: 'Route Map',
    icon: Icons.map_outlined,
    selectedIcon: Icons.map,
    description:
        'Live Google Maps route for the day\'s drop-offs, with turn-by-turn navigation and '
        'proof-of-delivery capture.',
    screenBuilder: (context, state) => const RouteMapScreen(),
  ),
  ModuleSpec(
    path: '/staff/history',
    label: 'History',
    icon: Icons.history,
    selectedIcon: Icons.history,
    description: 'Completed deliveries, delivery notes and signatures.',
    screenBuilder: (context, state) => const DeliveryHistoryScreen(),
  ),
  const ModuleSpec(
    path: '/staff/profile',
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    description: 'Your account, vehicle info, and availability status.',
  ),
];
