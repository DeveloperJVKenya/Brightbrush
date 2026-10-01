import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../logging/app_logger.dart';
import 'browser_online.dart';

/// How usable the internet connection is right now.
enum NetQuality {
  /// Reachable and responsive.
  online,

  /// Reachable but slow (or dropping requests) — things still work, slowly.
  weak,

  /// No network, or connected to Wi-Fi/data that doesn't reach the internet.
  offline,
}

@immutable
class ConnectionInfo {
  const ConnectionInfo({
    required this.quality,
    this.hasNetwork = true,
    this.lastLatency,
    this.checking = false,
  });

  final NetQuality quality;

  /// The device has Wi-Fi or mobile data switched on (it may still not
  /// reach the internet — e.g. a captive portal or no airtime).
  final bool hasNetwork;
  final Duration? lastLatency;
  final bool checking;

  bool get isOffline => quality == NetQuality.offline;

  ConnectionInfo copyWith({
    NetQuality? quality,
    bool? hasNetwork,
    Duration? lastLatency,
    bool? checking,
  }) => ConnectionInfo(
    quality: quality ?? this.quality,
    hasNetwork: hasNetwork ?? this.hasNetwork,
    lastLatency: lastLatency ?? this.lastLatency,
    checking: checking ?? this.checking,
  );
}

/// Watches the connection: the OS network state (connectivity_plus) plus a
/// small timed request to our own site, so "connected to Wi-Fi but no
/// internet" and "very slow" are told apart from "fine". Checks more often
/// while things are bad, and again whenever the network or app state
/// changes.
class ConnectionStatusNotifier extends Notifier<ConnectionInfo> {
  static const _slow = Duration(milliseconds: 2500);
  static const _timeout = Duration(seconds: 8);
  static const _okInterval = Duration(seconds: 60);
  static const _badInterval = Duration(seconds: 10);

  StreamSubscription<Object>? _sub;
  AppLifecycleListener? _lifecycle;
  Timer? _timer;
  bool _probing = false;
  int _slowStreak = 0;

  @override
  ConnectionInfo build() {
    // Browsers report online/offline themselves (the connectivity plugin's
    // web registration proved unreliable in release builds); phones use the
    // plugin.
    final browserChanges = browserOnlineChanges();
    _sub = browserChanges != null
        ? browserChanges.listen(_onNetworkChanged)
        : Connectivity().onConnectivityChanged.listen(
            (r) =>
                _onNetworkChanged(r.any((c) => c != ConnectivityResult.none)),
          );
    _lifecycle = AppLifecycleListener(onResume: check);
    ref.onDispose(() {
      _sub?.cancel();
      _lifecycle?.dispose();
      _timer?.cancel();
    });
    Future.microtask(() async {
      try {
        final online =
            browserIsOnline() ??
            (await Connectivity().checkConnectivity()).any(
              (c) => c != ConnectivityResult.none,
            );
        _onNetworkChanged(online);
      } catch (_) {
        unawaited(check());
      }
    });
    return const ConnectionInfo(quality: NetQuality.online);
  }

  void _onNetworkChanged(bool hasNetwork) {
    if (!hasNetwork) {
      _set(
        const ConnectionInfo(quality: NetQuality.offline, hasNetwork: false),
      );
      return;
    }
    state = state.copyWith(hasNetwork: true);
    unawaited(check());
  }

  /// Checks right now (also the banner's "Retry").
  Future<void> check() async {
    if (_probing) return;
    _probing = true;
    state = state.copyWith(checking: true);
    final started = DateTime.now();
    NetQuality quality;
    Duration? latency;
    try {
      final res = await http
          .get(_probeUri(), headers: const {'Cache-Control': 'no-cache'})
          .timeout(_timeout);
      latency = DateTime.now().difference(started);
      if (res.statusCode >= 500) throw StateError('status ${res.statusCode}');
      _slowStreak = latency > _slow ? _slowStreak + 1 : 0;
      // One slow answer can be a blip; two in a row is a weak connection.
      quality = _slowStreak >= 2 ? NetQuality.weak : NetQuality.online;
    } on TimeoutException {
      _slowStreak++;
      quality = _slowStreak >= 2 ? NetQuality.offline : NetQuality.weak;
    } catch (e) {
      quality = NetQuality.offline;
      _slowStreak = 0;
    } finally {
      _probing = false;
    }
    _set(
      ConnectionInfo(
        quality: quality,
        hasNetwork: state.hasNetwork,
        lastLatency: latency,
      ),
    );
  }

  void _set(ConnectionInfo next) {
    if (next.quality != state.quality) {
      appLogger.i('[net] ${state.quality.name} -> ${next.quality.name}');
    }
    state = next;
    _timer?.cancel();
    _timer = Timer(
      next.quality == NetQuality.online ? _okInterval : _badInterval,
      check,
    );
  }

  /// A tiny file on our own site (same origin on the web, so no CORS), with
  /// a cache-buster so neither the browser nor the service worker answers.
  Uri _probeUri() {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final base = kIsWeb ? Uri.base : Uri.parse('https://bright-brush.web.app/');
    return base.resolve('version.json?probe=$stamp');
  }
}

final connectionStatusProvider =
    NotifierProvider<ConnectionStatusNotifier, ConnectionInfo>(
      ConnectionStatusNotifier.new,
    );

/// True while the device can't reach the internet.
final isOfflineProvider = Provider<bool>(
  (ref) => ref.watch(connectionStatusProvider).isOffline,
);
