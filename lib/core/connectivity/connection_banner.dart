import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../l10n/current_l10n.dart';
import 'connection_status.dart';

/// Wraps every page (from MaterialApp.builder) with a slim status bar at the
/// top while the connection is bad. It never blocks the page: everything
/// already loaded stays on screen (served from the offline cache), and the
/// bar says what's happening and how to fix it.
class ConnectionBannerHost extends ConsumerStatefulWidget {
  const ConnectionBannerHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConnectionBannerHost> createState() =>
      _ConnectionBannerHostState();
}

class _ConnectionBannerHostState extends ConsumerState<ConnectionBannerHost> {
  bool _showBackOnline = false;
  bool _weakDismissed = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NetQuality>(connectionStatusProvider.select((s) => s.quality), (
      prev,
      next,
    ) {
      if (next != NetQuality.weak) _weakDismissed = false;
      if (prev != null &&
          prev != NetQuality.online &&
          next == NetQuality.online) {
        setState(() => _showBackOnline = true);
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showBackOnline = false);
        });
      } else if (next != NetQuality.online) {
        _hideTimer?.cancel();
        if (_showBackOnline) setState(() => _showBackOnline = false);
      }
    });
    final info = ref.watch(connectionStatusProvider);
    appIsOffline = info.isOffline;

    Widget? bar;
    if (info.quality == NetQuality.offline) {
      bar = _Bar(info: info, kind: _Kind.offline);
    } else if (info.quality == NetQuality.weak && !_weakDismissed) {
      bar = _Bar(
        info: info,
        kind: _Kind.weak,
        onDismiss: () => setState(() => _weakDismissed = true),
      );
    } else if (_showBackOnline) {
      bar = _Bar(info: info, kind: _Kind.back);
    }

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: bar == null
              ? const SizedBox(width: double.infinity)
              : Material(
                  color: Colors.transparent,
                  child: SafeArea(bottom: false, child: bar),
                ),
        ),
        Expanded(
          // The bar already sits below the status bar, so the page under
          // it must not add that space again.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: bar != null,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

enum _Kind { offline, weak, back }

class _Bar extends ConsumerWidget {
  const _Bar({required this.info, required this.kind, this.onDismiss});

  final ConnectionInfo info;
  final _Kind kind;
  final VoidCallback? onDismiss;

  bool get _canOpenSettings =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _openSettings() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android 10+: the Internet panel (Wi-Fi + mobile data together).
        await AppSettings.openAppSettingsPanel(
          AppSettingsPanelType.internetConnectivity,
        );
      } else {
        await AppSettings.openAppSettings(type: AppSettingsType.wifi);
      }
    } catch (_) {
      await AppSettings.openAppSettings(type: AppSettingsType.wireless);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final (
      Color bg,
      Color fg,
      IconData icon,
      String title,
      String? body,
    ) = switch (kind) {
      _Kind.offline => (
        const Color(0xFF3B0D11),
        Colors.white,
        Icons.wifi_off_rounded,
        l10n.netOfflineTitle,
        info.hasNetwork ? l10n.netOfflineNoInternetBody : l10n.netOfflineBody,
      ),
      _Kind.weak => (
        const Color(0xFFFFF4D6),
        const Color(0xFF5C3B00),
        Icons.network_check_rounded,
        l10n.netWeakTitle,
        l10n.netWeakBody,
      ),
      _Kind.back => (
        const Color(0xFF0E7A43),
        Colors.white,
        Icons.wifi_rounded,
        l10n.netBackOnline,
        null,
      ),
    };
    final textTheme = Theme.of(context).textTheme;
    final narrow = MediaQuery.sizeOf(context).width < 520;

    final actions = <Widget>[
      if (kind == _Kind.offline && _canOpenSettings)
        TextButton(
          onPressed: _openSettings,
          style: TextButton.styleFrom(
            foregroundColor: fg,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(l10n.netOpenSettings),
        ),
      if (kind != _Kind.back)
        info.checking
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
              )
            : TextButton(
                onPressed: () =>
                    ref.read(connectionStatusProvider.notifier).check(),
                style: TextButton.styleFrom(
                  foregroundColor: fg,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(l10n.retry),
              ),
      if (onDismiss != null)
        // No tooltip: this bar sits above the Navigator, outside any Overlay.
        Semantics(
          button: true,
          label: l10n.netDismiss,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: Icon(Icons.close_rounded, size: 18, color: fg),
          ),
        ),
    ];

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(
            color: fg,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (body != null)
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: fg.withValues(alpha: 0.9),
            ),
          ),
      ],
    );

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        color: bg,
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: narrow && actions.length > 1
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 20, color: fg),
                      const SizedBox(width: 10),
                      Expanded(child: text),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(children: actions),
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 10),
                  Expanded(child: text),
                  ...actions,
                ],
              ),
      ),
    );
  }
}
