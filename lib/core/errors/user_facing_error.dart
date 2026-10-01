import 'package:cloud_functions/cloud_functions.dart';

import '../l10n/current_l10n.dart';
import 'server_messages.dart';

/// Turns a raw exception (Firestore, Storage, network, Firebase AI/Gemini,
/// etc.) into a short, plain-language message safe to show to end users,
/// in the language the app is showing.
///
/// Technical detail — error codes, SDK/class names, stack frames — should
/// stay in `appLogger` calls at the call site (most already log the raw
/// `error`/`stackTrace`); this is the only thing that should ever reach a
/// [SnackBar] or [EmptyState] message.
String friendlyError(Object error) {
  final l = l10nNow;
  final raw = error.toString().toLowerCase();
  bool has(String needle) => raw.contains(needle);
  final looksNetwork =
      has('socketexception') ||
      has('failed host lookup') ||
      has('clientexception') ||
      has('network') ||
      has('failed to fetch') ||
      has('timeoutexception') ||
      has('connection') ||
      has('unavailable') ||
      has('deadline');

  // While the connection monitor says we're offline, anything that looks
  // like a network failure gets the clear "you're offline" message.
  if (appIsOffline && (looksNetwork || has('internal'))) {
    return l.netActionNeedsInternet;
  }

  // Our Cloud Functions write these messages for end users (e.g. "Caps has
  // a minimum order of 50"), so they're shown as-is (translated when the
  // app is in Kiswahili) rather than collapsed into a generic sentence.
  if (error is FirebaseFunctionsException &&
      _userFacingFunctionCodes.contains(error.code) &&
      (error.message ?? '').isNotEmpty) {
    return translateServerMessage(error.message!);
  }

  if (has('socketexception') ||
      has('failed host lookup') ||
      has('clientexception') ||
      has('network') ||
      has('failed to fetch') ||
      has('timeoutexception') ||
      has('connection')) {
    return l.errNetwork;
  }
  if (has('permission-denied') ||
      has('permission_denied') ||
      has('permission denied')) {
    return l.errPermission;
  }
  if (has('vertexai') ||
      has('generativelanguage') ||
      has('generativemodel') ||
      has('gemini') ||
      has('firebase ai') ||
      has('quota') ||
      has('resource_exhausted') ||
      has(' 429')) {
    return l.errAssistant;
  }
  if (has('unavailable') || has('deadline')) {
    return l.errSlow;
  }
  if (has('not-found') || has('not_found')) {
    return l.errNotFound;
  }
  return l.errGeneric;
}

const _userFacingFunctionCodes = {
  'invalid-argument',
  'failed-precondition',
  'resource-exhausted',
  'not-found',
  'permission-denied',
  'unauthenticated',
  'unavailable',
};
