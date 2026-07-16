import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/settings/app_font.dart';
import '../../../core/settings/settings_providers.dart';

/// Personal display preferences, reachable from every role via the shell's
/// app bar — not role-gated, since appearance is a per-device/per-user
/// choice, not a permission.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final font = ref.watch(appFontProvider);
    final textScale = ref.watch(textScaleProvider);
    final reduceMotion = ref.watch(reduceMotionProvider);
    final inAppNotifications = ref.watch(inAppNotificationsEnabledProvider);
    final role = ref.watch(resolvedRoleProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader(title: 'Appearance', icon: Icons.palette_outlined),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Follow your device, or lock it to light or dark.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) =>
                        ref.read(themeModeProvider.notifier).set(selection.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Font', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Pick whichever reads best to you — applies everywhere, instantly.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  for (final option in AppFont.values) ...[
                    _FontOptionTile(
                      option: option,
                      selected: option == font,
                      onTap: () => ref.read(appFontProvider.notifier).set(option),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Accessibility', icon: Icons.accessibility_new_outlined),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Text size', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Applies across the whole app, independent of your device\'s own text size.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Row(
                    children: [
                      const Text('A', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: Slider(
                          value: textScale,
                          min: TextScaleController.min,
                          max: TextScaleController.max,
                          divisions: 9,
                          label: '${(textScale * 100).round()}%',
                          onChanged: (v) => ref.read(textScaleProvider.notifier).set(v),
                        ),
                      ),
                      const Text('A', style: TextStyle(fontSize: 22)),
                    ],
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reduce motion'),
                    subtitle: const Text('Skip entrance/stagger animations on lists and grids.'),
                    value: reduceMotion,
                    onChanged: (v) => ref.read(reduceMotionProvider.notifier).set(v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Notifications', icon: Icons.notifications_outlined),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              title: const Text('In-app notifications'),
              subtitle: const Text('Show the announcement banner on Home. This doesn\'t send push alerts.'),
              value: inAppNotifications,
              onChanged: (v) => ref.read(inAppNotificationsEnabledProvider.notifier).set(v),
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: 'About & support', icon: Icons.info_outline),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                const _AppVersionTile(),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined),
                  title: const Text('Contact support'),
                  subtitle: const Text('Get help with an order, a design, or anything else.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openSupport(context, role),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openSupport(BuildContext context, AppRole? role) {
    // Only the customer role has an in-app Support screen; every other
    // role falls back to email, since Support tickets are customer-facing.
    if (role == AppRole.user) {
      context.go('/customer/support');
    } else {
      launchUrl(Uri.parse('mailto:support@brightbrushcreations.com'));
    }
  }
}

class _AppVersionTile extends StatelessWidget {
  const _AppVersionTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return ListTile(
          leading: const Icon(Icons.apps_outlined),
          title: const Text('BrightBrush Creations'),
          subtitle: Text(info == null ? 'Loading version…' : 'Version ${info.version} (${info.buildNumber})'),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _FontOptionTile extends StatelessWidget {
  const _FontOptionTile({required this.option, required this.selected, required this.onTap});

  final AppFont option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        fontFamily: option.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.description,
                      style: TextStyle(
                        fontFamily: option.fontFamily,
                        fontSize: 12,
                        color: selected
                            ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: theme.colorScheme.onPrimaryContainer, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
