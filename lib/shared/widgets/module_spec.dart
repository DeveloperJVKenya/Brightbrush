import 'package:flutter/material.dart';

/// Declarative description of one section within a role: the nav entry,
/// the route it lives at, and the copy shown on its placeholder screen
/// until the real feature is implemented.
class ModuleSpec {
  const ModuleSpec({
    required this.path,
    required this.label,
    required this.icon,
    IconData? selectedIcon,
    required this.description,
  }) : selectedIcon = selectedIcon ?? icon;

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String description;
}
