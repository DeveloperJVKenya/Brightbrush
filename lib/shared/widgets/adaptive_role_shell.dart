import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'brand_mark.dart';
import 'role_nav_item.dart';

/// Responsive navigation frame shared by all four role sections.
///
/// Wide screens (web/desktop/tablet landscape) get a persistent rail with a
/// branded header; narrow screens (phones) get a Drawer plus a bottom bar
/// with the first few destinations. The chrome is intentionally neutral
/// (graphite/off-white, not a flat red band) with the brand red reserved
/// for the active-state indicator and the gradient hairline under the app
/// bar — accent, not wallpaper.
class AdaptiveRoleShell extends StatelessWidget {
  const AdaptiveRoleShell({
    super.key,
    required this.roleLabel,
    required this.items,
    required this.currentPath,
    required this.onDestinationSelected,
    required this.onSwitchRole,
    required this.onOpenSettings,
    required this.child,
  });

  final String roleLabel;
  final List<RoleNavItem> items;
  final String currentPath;
  final ValueChanged<String> onDestinationSelected;
  final VoidCallback onSwitchRole;
  final VoidCallback onOpenSettings;
  final Widget child;

  // Picks the item whose path is the *longest* matching prefix, not the
  // first one found: '/customer' is a prefix of every path under it, so a
  // naive first-match would always highlight Home instead of e.g. Packages.
  int get _selectedIndex {
    var bestIndex = 0;
    var bestLength = -1;
    for (var i = 0; i < items.length; i++) {
      final path = items[i].path;
      final matches = currentPath == path || currentPath.startsWith('$path/');
      if (matches && path.length > bestLength) {
        bestIndex = i;
        bestLength = path.length;
      }
    }
    return bestIndex;
  }

  static const double _wideBreakpoint = 900;
  static const int _bottomBarItemCount = 4;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        if (isWide) {
          return _WideLayout(
            roleLabel: roleLabel,
            items: items,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => onDestinationSelected(items[i].path),
            onSwitchRole: onSwitchRole,
            onOpenSettings: onOpenSettings,
            child: child,
          );
        }
        return _NarrowLayout(
          roleLabel: roleLabel,
          items: items,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => onDestinationSelected(items[i].path),
          onSwitchRole: onSwitchRole,
          onOpenSettings: onOpenSettings,
          bottomBarItemCount: _bottomBarItemCount,
          child: child,
        );
      },
    );
  }
}

/// A 2px brand-gradient hairline used instead of a colored app bar fill —
/// enough of a signature to read as "designed," restrained enough not to
/// shout on every screen.
class _GradientHairline extends StatelessWidget implements PreferredSizeWidget {
  const _GradientHairline();

  @override
  Widget build(BuildContext context) {
    return Container(height: 2, decoration: const BoxDecoration(gradient: BrandColors.brandGradient));
  }

  @override
  Size get preferredSize => const Size.fromHeight(2);
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.roleLabel,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onSwitchRole,
    required this.onOpenSettings,
    required this.child,
  });

  final String roleLabel;
  final List<RoleNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSwitchRole;
  final VoidCallback onOpenSettings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final extended = MediaQuery.sizeOf(context).width >= 1200;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const BrandMark(size: 30),
            const SizedBox(width: 12),
            Flexible(
              child: Text('BrightBrush Creations', overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
            const SizedBox(width: 10),
            _RolePill(label: roleLabel),
          ],
        ),
        bottom: const _GradientHairline(),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Switch role (demo)',
            onPressed: onSwitchRole,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          _SideRail(
            extended: extended,
            items: items,
            selectedIndex: selectedIndex,
            onSelected: onDestinationSelected,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Custom side rail, built instead of [NavigationRail].
///
/// [NavigationRail] positions its destinations using an internal
/// `Expanded`/flex layout that assumes a bounded height and doesn't scroll —
/// a role with many sections (Admin has 10) can overflow it on a short or
/// resized desktop window, and there's no supported way to make it
/// scrollable without fighting its internals. A plain scrollable list of
/// tiles sidesteps the problem entirely and degrades gracefully: it just
/// scrolls instead of overflowing.
class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.extended,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final bool extended;
  final List<RoleNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: extended ? 232 : 88,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(right: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = index == selectedIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 0, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: extended
                      ? Row(
                          children: [
                            Icon(
                              selected ? item.selectedIcon : item.icon,
                              size: 22,
                              color: selected
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                item.label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                  color: selected
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              selected ? item.selectedIcon : item.icon,
                              size: 22,
                              color: selected
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                color: selected
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.roleLabel,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onSwitchRole,
    required this.onOpenSettings,
    required this.bottomBarItemCount,
    required this.child,
  });

  final String roleLabel;
  final List<RoleNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSwitchRole;
  final VoidCallback onOpenSettings;
  final int bottomBarItemCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomItems = items.take(bottomBarItemCount).toList();
    final overflowItems = items.skip(bottomBarItemCount).toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const BrandMark(size: 28),
            const SizedBox(width: 10),
            Flexible(child: Text(roleLabel, overflow: TextOverflow.ellipsis, maxLines: 1)),
          ],
        ),
        bottom: const _GradientHairline(),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Switch role (demo)',
            onPressed: onSwitchRole,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
        ],
      ),
      drawer: overflowItems.isEmpty
          ? null
          : Drawer(
              child: SafeArea(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const BrandMark(size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              roleLabel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final item in overflowItems)
                      ListTile(
                        leading: Icon(item.icon),
                        title: Text(item.label),
                        selected: items.indexOf(item) == selectedIndex,
                        selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onTap: () {
                          Navigator.of(context).pop();
                          onDestinationSelected(items.indexOf(item));
                        },
                      ),
                  ],
                ),
              ),
            ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < bottomItems.length ? selectedIndex : 0,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          for (final item in bottomItems)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            ),
        ],
      ),
    );
  }
}
