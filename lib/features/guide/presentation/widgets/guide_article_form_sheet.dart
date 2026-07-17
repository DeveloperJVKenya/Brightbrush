import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/app_role.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/errors/user_facing_error.dart';
import '../../../../core/logging/app_logger.dart';
import '../../application/guide_providers.dart';
import '../../domain/guide_article.dart';

Future<void> showGuideArticleFormSheet(BuildContext context, WidgetRef ref, {GuideArticle? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => _GuideArticleFormSheet(existing: existing),
  );
}

class _GuideArticleFormSheet extends ConsumerStatefulWidget {
  const _GuideArticleFormSheet({this.existing});

  final GuideArticle? existing;

  @override
  ConsumerState<_GuideArticleFormSheet> createState() => _GuideArticleFormSheetState();
}

class _GuideArticleFormSheetState extends ConsumerState<_GuideArticleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _question = TextEditingController(text: widget.existing?.question ?? '');
  late final _answer = TextEditingController(text: widget.existing?.answer ?? '');
  late final _section = TextEditingController(text: widget.existing?.section ?? '');
  late final _keywords = TextEditingController(text: widget.existing?.keywords.join(', ') ?? '');
  final Set<AppRole> _roles = {};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _roles.addAll((widget.existing?.roles ?? const <String>[]).map(AppRole.fromRoleName));
  }

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    _section.dispose();
    _keywords.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one role'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _saving = true);

    final repo = ref.read(guideArticlesRepositoryProvider);
    final uid = ref.read(currentUidProvider);
    final keywords = _keywords.text.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).take(15).toList();

    try {
      final article = GuideArticle(
        id: widget.existing?.id ?? '',
        question: _question.text.trim(),
        answer: _answer.text.trim(),
        roles: _roles.map((r) => r.name).toList(),
        section: _section.text.trim().isEmpty ? null : _section.text.trim(),
        keywords: keywords,
        createdBy: widget.existing?.createdBy ?? uid ?? '',
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.existing == null) {
        final id = await repo.create(article, uid: uid ?? '');
        appLogger.i('[guide] Created article $id (createdBy=$uid)');
      } else {
        await repo.update(article);
        appLogger.i('[guide] Updated article ${article.id}');
      }

      if (mounted) Navigator.of(context).pop();
    } catch (error, stack) {
      appLogger.e('[guide] Failed to save article', error: error, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t save: ${friendlyError(error)}'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 4, bottom: MediaQuery.viewInsetsOf(context).bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'New guide article' : 'Edit guide article',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _question,
                decoration: const InputDecoration(labelText: 'Question'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a question' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _answer,
                decoration: const InputDecoration(labelText: 'Answer'),
                maxLines: 5,
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter an answer' : null,
              ),
              const SizedBox(height: 12),
              Text('Applies to', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final role in [AppRole.user, AppRole.deliveryStaff, AppRole.systemManager, AppRole.admin])
                    FilterChip(
                      label: Text(role.label),
                      selected: _roles.contains(role),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _roles.add(role);
                        } else {
                          _roles.remove(role);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _section,
                decoration: const InputDecoration(labelText: 'Related section path (optional, e.g. /manager/staff)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _keywords,
                decoration: const InputDecoration(labelText: 'Extra search keywords (comma separated, optional)'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.existing == null ? 'Add article' : 'Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
