import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/user_facing_error.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../catalog/application/ai_catalog_search_service.dart';
import '../../../catalog/application/catalog_providers.dart';

/// "Ask AI" entry point for the catalog: the customer describes what they
/// need in plain language, Gemini maps it to the closest category (from the
/// app's real enum — it can't invent one) plus a few keywords, and those
/// get applied straight to the existing category filter + substring search.
class AiSearchDialog extends ConsumerStatefulWidget {
  const AiSearchDialog({super.key});

  @override
  ConsumerState<AiSearchDialog> createState() => _AiSearchDialogState();
}

class _AiSearchDialogState extends ConsumerState<AiSearchDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final request = _controller.text.trim();
    if (request.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final suggestion = await ref.read(aiCatalogSearchServiceProvider).suggest(request);
      ref.read(catalogCategoryFilterProvider.notifier).state = suggestion.category;
      ref.read(catalogSearchQueryProvider.notifier).state = suggestion.keywords.join(' ');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              suggestion.rationale.isEmpty ? 'Filters updated.' : suggestion.rationale,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error, stack) {
      appLogger.e('[ai-search] Failed to reach AI catalog search', error: error, stackTrace: stack);
      setState(() => _error = 'Couldn\'t reach the AI assistant: ${friendlyError(error)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          const Text('Ask what you need'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Describe the occasion or item in your own words — e.g. "something for a corporate '
              'summer picnic, 60 people" — and we\'ll set the right filters.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'What are you branding, and for what?'),
              onSubmitted: (_) => _ask(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _loading ? null : _ask,
          icon: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome_rounded, size: 18),
          label: const Text('Ask'),
        ),
      ],
    );
  }
}
