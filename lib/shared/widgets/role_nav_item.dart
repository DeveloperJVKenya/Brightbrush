import 'package:flutter/material.dart';

/// One entry in a role's side/bottom navigation.
class RoleNavItem {
  const RoleNavItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.description,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Shown as a hover tooltip on the nav destination — the same text
  /// already written for this section in its `ModuleSpec`.
  final String description;
}
