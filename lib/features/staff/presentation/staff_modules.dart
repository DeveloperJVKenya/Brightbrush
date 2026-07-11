import 'package:flutter/material.dart';

import '../../../shared/widgets/module_spec.dart';

/// Sections available to Delivery Staff.
const List<ModuleSpec> staffModules = [
  ModuleSpec(
    path: '/staff',
    label: 'My Deliveries',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
    description: 'Deliveries assigned to you today, grouped by route and priority.',
  ),
  ModuleSpec(
    path: '/staff/map',
    label: 'Route Map',
    icon: Icons.map_outlined,
    selectedIcon: Icons.map,
    description:
        'Live Google Maps route for the day\'s drop-offs, with turn-by-turn navigation and '
        'proof-of-delivery capture.',
  ),
  ModuleSpec(
    path: '/staff/history',
    label: 'History',
    icon: Icons.history,
    selectedIcon: Icons.history,
    description: 'Completed deliveries, delivery notes and signatures.',
  ),
  ModuleSpec(
    path: '/staff/profile',
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    description: 'Your account, vehicle info, and availability status.',
  ),
];
