/// Turns a raw exception (Firestore, Storage, network, Firebase AI/Gemini,
/// etc.) into a short, plain-language message safe to show to end users.
///
/// Technical detail — error codes, SDK/class names, stack frames — should
/// stay in `appLogger` calls at the call site (most already log the raw
/// `error`/`stackTrace`); this is the only thing that should ever reach a
/// [SnackBar] or [EmptyState] message.
String friendlyError(Object error) {
  final raw = error.toString().toLowerCase();
  bool has(String needle) => raw.contains(needle);

  if (has('socketexception') ||
      has('failed host lookup') ||
      has('clientexception') ||
      has('network') ||
      has('timeoutexception') ||
      has('connection')) {
    return 'Please check your internet connection and try again.';
  }
  if (has('permission-denied') || has('permission_denied') || has('permission denied')) {
    return 'You don\'t have permission to do this. Contact an admin if you think this is a mistake.';
  }
  if (has('vertexai') ||
      has('generativelanguage') ||
      has('generativemodel') ||
      has('gemini') ||
      has('firebase ai') ||
      has('quota') ||
      has('resource_exhausted') ||
      has(' 429')) {
    return 'The assistant is temporarily unavailable right now. Please try again shortly.';
  }
  if (has('unavailable') || has('deadline')) {
    return 'That\'s taking longer than expected. Please try again.';
  }
  if (has('not-found') || has('not_found')) {
    return 'That couldn\'t be found — it may have been removed.';
  }
  return 'Something went wrong. Please try again.';
}
