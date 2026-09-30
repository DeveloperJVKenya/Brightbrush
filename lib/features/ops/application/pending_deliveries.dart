import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/settings/shared_preferences_provider.dart';
import 'ops_providers.dart';

/// A delivery confirmed with the customer's code while the driver had no
/// signal. It is kept on the phone and sent as soon as it's back online.
class PendingDelivery {
  const PendingDelivery({
    required this.orderId,
    required this.orderLabel,
    required this.recipientName,
    required this.code,
    required this.savedAt,
    this.error,
  });

  final String orderId;
  final String orderLabel;
  final String recipientName;
  final String code;
  final DateTime savedAt;

  /// Set when the server refused it (e.g. wrong code) — needs the driver.
  final String? error;

  PendingDelivery copyWith({String? error}) => PendingDelivery(
    orderId: orderId,
    orderLabel: orderLabel,
    recipientName: recipientName,
    code: code,
    savedAt: savedAt,
    error: error,
  );

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'orderLabel': orderLabel,
    'recipientName': recipientName,
    'code': code,
    'savedAt': savedAt.toIso8601String(),
    'error': ?error,
  };

  static PendingDelivery fromJson(Map<String, dynamic> j) => PendingDelivery(
    orderId: j['orderId'] as String,
    orderLabel: j['orderLabel'] as String? ?? '',
    recipientName: j['recipientName'] as String? ?? '',
    code: j['code'] as String? ?? '',
    savedAt: DateTime.tryParse(j['savedAt'] as String? ?? '') ?? DateTime.now(),
    error: j['error'] as String?,
  );
}

/// True when an error means "couldn't reach the server", as opposed to the
/// server saying no.
bool isOfflineError(Object error) {
  if (error is FirebaseFunctionsException) {
    return error.code == 'unavailable' || error.code == 'deadline-exceeded';
  }
  final text = error.toString().toLowerCase();
  return text.contains('network') ||
      text.contains('socket') ||
      text.contains('failed host lookup') ||
      text.contains('failed to fetch');
}

class PendingDeliveriesNotifier extends Notifier<List<PendingDelivery>> {
  static const _key = 'pendingDeliveries.v1';
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _flushing = false;

  @override
  List<PendingDelivery> build() {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) unawaited(flush());
    });
    ref.onDispose(() => _sub?.cancel());
    final saved = _read();
    if (saved.isNotEmpty) Future.microtask(flush);
    return saved;
  }

  List<PendingDelivery> _read() {
    try {
      final raw = ref.read(sharedPreferencesProvider).getString(_key);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List)
          .map(
            (e) =>
                PendingDelivery.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      appLogger.w('[pod-queue] unreadable queue, clearing', error: e);
      return const [];
    }
  }

  void _save(List<PendingDelivery> list) {
    state = list;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(_key, jsonEncode(list.map((p) => p.toJson()).toList())),
    );
  }

  void enqueue(PendingDelivery p) {
    _save([...state.where((x) => x.orderId != p.orderId), p]);
    appLogger.i('[pod-queue] saved ${p.orderId} for later');
  }

  void remove(String orderId) =>
      _save(state.where((x) => x.orderId != orderId).toList());

  /// Sends everything waiting. Items the server refuses are kept with the
  /// reason so the driver can deal with them; network failures just wait
  /// for the next try.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      for (final p in [...state]) {
        if (p.error != null) continue;
        try {
          await ref
              .read(opsRepositoryProvider)
              .completeDelivery(
                orderId: p.orderId,
                recipientName: p.recipientName,
                code: p.code,
              );
          remove(p.orderId);
          appLogger.i('[pod-queue] sent ${p.orderId}');
        } catch (error) {
          if (isOfflineError(error)) break;
          _save([
            for (final x in state)
              x.orderId == p.orderId
                  ? x.copyWith(error: friendlyError(error))
                  : x,
          ]);
        }
      }
    } finally {
      _flushing = false;
    }
  }
}

final pendingDeliveriesProvider =
    NotifierProvider<PendingDeliveriesNotifier, List<PendingDelivery>>(
      PendingDeliveriesNotifier.new,
    );

/// Shown on the driver's screens while deliveries are waiting to be sent.
class PendingDeliveriesBanner extends ConsumerWidget {
  const PendingDeliveriesBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingDeliveriesProvider);
    if (pending.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final failed = pending.where((p) => p.error != null).toList();
    final waiting = pending.length - failed.length;
    return Card(
      color: failed.isEmpty
          ? theme.colorScheme.secondaryContainer
          : theme.colorScheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (waiting > 0)
              Row(
                children: [
                  const Icon(Icons.cloud_upload_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$waiting delivery confirmation${waiting == 1 ? '' : 's'} '
                      'saved on this phone — sending when you\'re back online.',
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(pendingDeliveriesProvider.notifier).flush(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            for (final p in failed)
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${p.orderLabel}: ${p.error}')),
                  TextButton(
                    onPressed: () => ref
                        .read(pendingDeliveriesProvider.notifier)
                        .remove(p.orderId),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
