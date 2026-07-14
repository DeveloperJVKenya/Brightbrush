import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/catalog_category.dart';

/// Result of turning a free-text request ("something for a summer beach
/// event, 50 people") into a structured catalog filter: at most one
/// category (constrained to the app's real enum, so the model can't
/// hallucinate a category that doesn't exist) plus a handful of keywords
/// fed straight into the existing substring search.
class AiCatalogSuggestion {
  const AiCatalogSuggestion({required this.category, required this.keywords, required this.rationale});

  final CatalogCategory? category;
  final List<String> keywords;
  final String rationale;
}

class AiCatalogSearchService {
  static const _model = 'gemini-2.5-flash';

  GenerativeModel _buildModel() {
    final googleAI = FirebaseAI.googleAI();
    return googleAI.generativeModel(
      model: _model,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'category': Schema.enumString(
              enumValues: [for (final c in CatalogCategory.values) c.name, 'none'],
              description: 'Best-matching branding category, or "none" if nothing fits clearly.',
            ),
            'keywords': Schema.array(
              items: Schema.string(),
              description: 'Up to 5 short search keywords pulled from the request (materials, colors, occasions).',
              maxItems: 5,
            ),
            'rationale': Schema.string(description: 'One short sentence explaining the suggestion.'),
          },
          optionalProperties: const ['category', 'keywords'],
        ),
      ),
    );
  }

  Future<AiCatalogSuggestion> suggest(String request) async {
    final model = _buildModel();
    final prompt =
        'A customer of a branding company (caps, t-shirts, hoodies, two-piece sets, water bottles, '
        'cutlery, embroidery) describes what they need. Map it to the closest matching category and '
        'a short list of search keywords.\n\nCustomer request: "$request"';

    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text;
    if (text == null || text.isEmpty) {
      return const AiCatalogSuggestion(category: null, keywords: [], rationale: 'No suggestion available.');
    }

    // responseSchema guarantees valid JSON shape, but decode defensively —
    // a model hiccup shouldn't crash the search bar.
    try {
      final decoded = jsonDecode(text) as Map<String, dynamic>;
      final categoryName = decoded['category'] as String?;
      final category =
          (categoryName == null || categoryName == 'none') ? null : CatalogCategory.fromName(categoryName);
      final keywords = (decoded['keywords'] as List?)?.map((e) => e.toString()).toList() ?? const [];
      final rationale = decoded['rationale'] as String? ?? '';
      return AiCatalogSuggestion(category: category, keywords: keywords, rationale: rationale);
    } catch (_) {
      return const AiCatalogSuggestion(category: null, keywords: [], rationale: 'Couldn\'t parse a suggestion.');
    }
  }
}

final aiCatalogSearchServiceProvider = Provider<AiCatalogSearchService>((ref) => AiCatalogSearchService());
