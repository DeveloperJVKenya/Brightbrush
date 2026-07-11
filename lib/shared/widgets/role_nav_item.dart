import 'package:flutter/material.dart';

/// One entry in a role's side/bottom navigation.
class RoleNavItem {
  const RoleNavItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
