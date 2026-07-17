import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../application/guide_providers.dart';
import '../domain/guide_article.dart';
import 'widgets/guide_article_form_sheet.dart';

/// Not a persistent nav item — reachable via a quick-link from the
/// Executive Dashboard, same mechanism as the Support Inbox. Admin/CEO and
/// Developer maintain the Guide's predefined content here; every role
/// reads it live via the Guide screen.
class GuideEditorScreen extends ConsumerWidget {
  const GuideEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final articlesAsync = ref.watch(allGuideArticlesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showGuideArticleFormSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New article'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Guide editor', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Predefined questions and answers shown in every role\'s Guide — edits here go live immediately, no app update needed.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: articlesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) {
                    appLogger.e('[guide] Failed to load articles', error: error, stackTrace: stack);
                    return EmptyState(
                        icon: Icons.cloud_off_rounded, title: 'Couldn\'t load articles', message: friendlyError(error));
                  },
                  data: (articles) {
                    if (articles.isEmpty) {
                      return const EmptyState(
                        icon: Icons.menu_book_outlined,
                        title: 'No articles yet',
                        message: 'Add the first question and answer for a role\'s Guide.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: articles.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _ArticleRow(article: articles[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleRow extends ConsumerWidget {
  const _ArticleRow({required this.article});

  final GuideArticle article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleLabels = article.roles.map((name) => AppRole.fromRoleName(name).label).join(', ');
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(article.question, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$roleLabels${article.section != null ? ' · ${article.section}' : ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showGuideArticleFormSheet(context, ref, existing: article),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref.read(guideArticlesRepositoryProvider).delete(article.id),
            ),
          ],
        ),
      ),
    );
  }
}
