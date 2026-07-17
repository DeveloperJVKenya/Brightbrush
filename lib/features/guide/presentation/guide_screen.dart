import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/search/search_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_search_field.dart';
import '../../../shared/widgets/typewriter_text.dart';
import '../application/guide_assistant_service.dart';
import '../application/guide_providers.dart';
import '../domain/guide_article.dart';

final _guideSearchProvider = StateProvider<String>((ref) => '');

/// Answers pop up centered over the page, in a rounded, colored card, rather
/// than sliding up from the bottom — a small "reveal" moment for what's
/// otherwise a plain Q&A.
Future<void> _showAnswerDialog(
  BuildContext context, {
  required String question,
  required String answer,
  bool fromCache = false,
}) {
  return showGeneralDialog(
    context: context,
    barrierLabel: 'Answer',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return Opacity(
        opacity: animation.value.clamp(0, 1),
        child: Transform.scale(
          scale: 0.85 + (0.15 * curved.value.clamp(0, 1)),
          child: _AnswerCard(question: question, answer: answer, fromCache: fromCache),
        ),
      );
    },
  );
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.question, required this.answer, required this.fromCache});

  final String question;
  final String answer;
  final bool fromCache;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
          child: Material(
            color: theme.colorScheme.surface,
            elevation: 12,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [theme.colorScheme.primaryContainer, theme.colorScheme.tertiaryContainer],
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.85),
                        child: Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          question,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (fromCache)
                  Container(
                    width: double.infinity,
                    color: theme.colorScheme.secondaryContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.offline_bolt_rounded, size: 15, color: theme.colorScheme.onSecondaryContainer),
                        const SizedBox(width: 6),
                        Text(
                          'Saved answer — shown while offline',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                        ),
                      ],
                    ),
                  ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                    child: TypewriterText(
                      text: answer,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Got it'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Role-tailored usage guide: a list of real predefined questions for the
/// signed-in role, plus a free-text fallback to the Gemini-backed
/// [GuideAssistantService] for anything not already covered. Predefined
/// answers are cached on-device so they keep working offline; the free-text
/// assistant always needs a live connection.
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
      if (mounted) _showAnswerDialog(context, question: question, answer: answer);
    } catch (error, stack) {
      appLogger.e('[guide] Assistant question failed', error: error, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(error)), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Widget _buildArticleList(BuildContext context, List<GuideArticle> articles, String query, {required bool offline}) {
    final theme = Theme.of(context);
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
    final palette = [theme.colorScheme.primaryContainer, theme.colorScheme.tertiaryContainer, theme.colorScheme.secondaryContainer];
    final onPalette = [theme.colorScheme.onPrimaryContainer, theme.colorScheme.onTertiaryContainer, theme.colorScheme.onSecondaryContainer];
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final article = filtered[index];
        final tone = index % palette.length;
        return Material(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _showAnswerDialog(context, question: article.question, answer: article.answer, fromCache: offline),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: palette[tone],
                    child: Icon(Icons.help_rounded, size: 18, color: onPalette[tone]),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          article.question,
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (article.answer.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            article.answer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final articlesAsync = ref.watch(myGuideArticlesProvider);
    final query = ref.watch(_guideSearchProvider);
    final role = ref.watch(resolvedRoleProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guide'),
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primaryContainer.withValues(alpha: 0.5), theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Answers for what you can do here — search below, or ask your own question.',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
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
                  error: (error, stack) {
                    appLogger.e('[guide] Failed to load articles', error: error, stackTrace: stack);
                    final cached = role == null ? const <GuideArticle>[] : readCachedGuideArticles(ref, role);
                    if (cached.isEmpty) {
                      return EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load the guide', message: friendlyError(error));
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.wifi_off_rounded, size: 16, color: theme.colorScheme.onSecondaryContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You\'re offline — showing saved answers. Asking something new needs a connection.',
                                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: _buildArticleList(context, cached, query, offline: true)),
                      ],
                    );
                  },
                  data: (articles) => _buildArticleList(context, articles, query, offline: false),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [theme.colorScheme.tertiaryContainer.withValues(alpha: 0.55), theme.colorScheme.primaryContainer.withValues(alpha: 0.55)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Ask something else — needs internet',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: TextField(
                              controller: _askController,
                              decoration: const InputDecoration(
                                hintText: 'Type your question…',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _askSomethingElse(articlesAsync.valueOrNull ?? const []),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _asking
                            ? const SizedBox(
                                width: 46,
                                height: 46,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2.4),
                                ),
                              )
                            : _SendButton(onPressed: () => _askSomethingElse(articlesAsync.valueOrNull ?? const [])),
                      ],
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

/// A modern, circular gradient send button — replaces the previous plain
/// filled [IconButton] for the "Ask something else" box.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: Ink(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
          ),
          boxShadow: [
            BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: 46,
            height: 46,
            child: Icon(Icons.send_rounded, size: 19, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
