import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Declarative description of one section within a role: the nav entry, the
/// route it lives at, and (once built) the real screen. Until a module has
/// a [screenBuilder], the router falls back to a placeholder built from
/// [label]/[description]/[icon] so every section is reachable from day one.
class ModuleSpec {
  const ModuleSpec({
    required this.path,
    required this.label,
    required this.icon,
    IconData? selectedIcon,
    required this.description,
    this.screenBuilder,
  }) : selectedIcon = selectedIcon ?? icon;

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String description;
  final Widget Function(BuildContext context, GoRouterState state)? screenBuilder;
}
