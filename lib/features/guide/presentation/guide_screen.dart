import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/search/search_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_search_field.dart';
import '../../../shared/widgets/typewriter_text.dart';
import '../application/guide_assistant_service.dart';
import '../application/guide_providers.dart';
import '../domain/guide_article.dart';

final _guideSearchProvider = StateProvider<String>((ref) => '');

void _showAnswerSheet(BuildContext context, {required String question, required String answer}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 4, bottom: MediaQuery.viewInsetsOf(context).bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(question, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TypewriterText(text: answer, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      );
    },
  );
}

/// Role-tailored usage guide: a list of real predefined questions for the
/// signed-in role, plus a free-text fallback to the Gemini-backed
/// [GuideAssistantService] for anything not already covered.
class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key});

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  final _askController = TextEditingController();
  bool _asking = false;

  @override
  void dispose() {
    _askController.dispose();
    super.dispose();
  }

  Future<void> _askSomethingElse(List<GuideArticle> knownArticles) async {
    final question = _askController.text.trim();
    if (question.isEmpty) return;
    final role = ref.read(resolvedRoleProvider).valueOrNull;
    if (role == null) return;

    setState(() => _asking = true);
    try {
      final answer = await ref.read(guideAssistantServiceProvider).ask(
            question: question,
            role: role,
            knownArticles: knownArticles,
          );
      _askController.clear();
      if (mounted) _showAnswerSheet(context, question: question, answer: answer);
    } catch (error) {
      appLogger.e('[guide] Assistant question failed', error: error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t reach the assistant: $error'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final articlesAsync = ref.watch(myGuideArticlesProvider);
    final query = ref.watch(_guideSearchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Guide')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Answers for what you can do here — search below, or ask your own question.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              LiveSearchField(
                hintText: 'Search questions, e.g. "assign order"',
                onChanged: (v) => ref.read(_guideSearchProvider.notifier).state = v,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: articlesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) =>
                      EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load the guide', message: '$error'),
                  data: (articles) {
                    final filtered = filterBySearch(articles, query, (a) => a.searchFields);
                    if (filtered.isEmpty) {
                      return EmptyState(
                        icon: Icons.menu_book_outlined,
                        title: articles.isEmpty ? 'Nothing here yet' : 'No matches',
                        message: articles.isEmpty
                            ? 'Ask a question below and the assistant will help.'
                            : 'Try a different search, or ask below.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final article = filtered[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: const Icon(Icons.help_outline_rounded),
                            title: Text(article.question),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showAnswerSheet(context, question: article.question, answer: article.answer),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _askController,
                        decoration: const InputDecoration(
                          hintText: 'Ask something else…',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _askSomethingElse(articlesAsync.valueOrNull ?? const []),
                      ),
                    ),
                    _asking
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            tooltip: 'Ask',
                            icon: const Icon(Icons.auto_awesome_rounded),
                            onPressed: () => _askSomethingElse(articlesAsync.valueOrNull ?? const []),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
