import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/logging/app_logger.dart';
import '../../admin/presentation/admin_modules.dart';
import '../../customer/presentation/customer_modules.dart';
import '../../manager/presentation/manager_modules.dart';
import '../../staff/presentation/staff_modules.dart';
import '../domain/guide_article.dart';

/// Answers a free-text question about how to use BrightBrush Creations,
/// scoped strictly to the signed-in role's real features. Reuses the same
/// `firebase_ai` construction as `AiCatalogSearchService` (catalog search),
/// just with a free-form text response instead of a JSON schema, since the
/// answer here is prose, not a structured filter.
class GuideAssistantService {
  static const _model = 'gemini-2.5-flash';

  /// Every predefined [GuideArticle] answer already covers real, human-
  /// reviewed ground truth — passed in as grounding context so the model
  /// prefers those over improvising, and only extends adjacent to them.
  Future<String> ask({
    required String question,
    required AppRole role,
    required List<GuideArticle> knownArticles,
  }) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: _model,
      systemInstruction: Content.system(_systemPrompt(role, knownArticles)),
    );

    try {
      final response = await model.generateContent([Content.text(question)]);
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        return 'I don\'t have an answer for that yet — try Support and a person on the team can help.';
      }
      return text;
    } catch (error, stack) {
      appLogger.e('[guide] ask() failed for role=${role.name}', error: error, stackTrace: stack);
      rethrow;
    }
  }

  String _systemPrompt(AppRole role, List<GuideArticle> knownArticles) {
    final modules = switch (role) {
      AppRole.user => customerModules,
      AppRole.deliveryStaff => staffModules,
      AppRole.systemManager => managerModules,
      AppRole.admin => adminModules,
      AppRole.developer => adminModules, // widest real feature set to ground against
    };
    final sectionList = modules.map((m) => '- ${m.label} (${m.path}): ${m.description}').join('\n');
    final articleList = knownArticles.isEmpty
        ? '(none yet)'
        : knownArticles.map((a) => 'Q: ${a.question}\nA: ${a.answer}').join('\n\n');

    return '''
You are the in-app Guide assistant for BrightBrush Creations, a branding/merchandising order-management system. You are answering a signed-in user with the role "${role.label}".

The real sections available to this role are:
$sectionList

Already-written answers for this role (prefer these; extend them for closely related follow-up questions, don't contradict them):
$articleList

Rules you must always follow:
1. Only answer questions about HOW TO USE the sections listed above — where to find something, what a button/screen does, what steps to take to complete a task.
2. NEVER explain or discuss the system's technical implementation: no code, frameworks, databases, hosting, APIs, architecture, or how anything is built. If asked about any of that (e.g. "what database do you use", "what language is this written in", "how is this coded"), politely decline in one sentence and suggest using Support for anything else.
3. If a question is about a feature that doesn't exist for this role, say so plainly and, if relevant, mention which role does have it — don't invent functionality.
4. Keep answers short and plain-language — a few sentences or a short numbered list, never a technical essay.
5. If you don't know, say so and suggest Support rather than guessing.
''';
  }
}

final guideAssistantServiceProvider = Provider<GuideAssistantService>((ref) => GuideAssistantService());
