import 'dart:async';

import 'app_logger.dart';

/// Logs a stream error (with full stack trace, for terminal tracing) and
/// then re-emits it unchanged — unlike [Stream.handleError], which would
/// swallow it and leave any listening `AsyncValue`/`StreamBuilder` stuck
/// showing stale or loading data forever instead of surfacing the error.
/// Firestore permission-denied errors show up exactly this way, so every
/// repository `.snapshots()` stream should run through this.
StreamTransformer<T, T> logStreamErrors<T>(String context) {
  return StreamTransformer.fromHandlers(
    handleError: (error, stack, sink) {
      appLogger.e(context, error: error, stackTrace: stack);
      sink.addError(error, stack);
    },
  );
}
