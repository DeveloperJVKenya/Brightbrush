/// Case-insensitive substring match: true if [query] appears anywhere in
/// [haystack] — at the start, in the middle, or at the end of a word. This
/// is deliberately `contains`, not `startsWith`: a search for "shirt" should
/// find "T-Shirt" just as readily as "shirt sizing guide".
bool matchesSubstring(String haystack, String query) {
  if (query.isEmpty) return true;
  return haystack.toLowerCase().contains(query.trim().toLowerCase());
}

/// True if [query] matches any of [fields] via [matchesSubstring]. Use this
/// to search across several fields of a model (name, description, tags...)
/// with one call.
bool matchesAnyField(Iterable<String> fields, String query) {
  if (query.trim().isEmpty) return true;
  return fields.any((field) => matchesSubstring(field, query));
}

/// Filters [items] to those where [fieldsOf] returns at least one field
/// containing [query] as a substring.
List<T> filterBySearch<T>(List<T> items, String query, Iterable<String> Function(T item) fieldsOf) {
  if (query.trim().isEmpty) return items;
  return items.where((item) => matchesAnyField(fieldsOf(item), query)).toList();
}
