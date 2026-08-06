import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PerspectiveResult {
  final bool isToxic;
  final double score;
  final String attribute;

  const PerspectiveResult({
    required this.isToxic,
    required this.score,
    required this.attribute,
  });
}

class PerspectiveService {
  static const String _apiKey = 'AIzaSyBBNbrPJZclEg5mWhZ4lxbrJstD8E2zlIA';
  static const double _toxicityThreshold = 0.50;

  static final RegExp _localProfanityRegex = RegExp(
    r'\b(puta|puto|hijo\s*de\s*puta|hijueputa|pendejo|pendeja|mierda|malparido|malparida|verga|concha\s*de\s*tu\s*madre|imbecil|imbécil|idiota|maricon|maricón|perra|bastardo|gran\s*puta)\b',
    caseSensitive: false,
  );

  static bool isLocalProfane(String text) {
    return _localProfanityRegex.hasMatch(text.trim());
  }

  static Future<PerspectiveResult> analyze(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const PerspectiveResult(isToxic: false, score: 0.0, attribute: 'TOXICITY');
    }

    if (isLocalProfane(trimmed)) {
      return const PerspectiveResult(
        isToxic: true,
        score: 1.0,
        attribute: 'PROFANITY_LOCAL',
      );
    }

    try {
      final url = Uri.parse(
        'https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze?key=$_apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'comment': {'text': trimmed},
          'languages': ['es', 'en'],
          'requestedAttributes': {
            'TOXICITY': {},
            'SEVERE_TOXICITY': {},
            'INSULT': {},
            'PROFANITY': {},
            'THREAT': {},
            'IDENTITY_ATTACK': {},
          },
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('Perspective API error (${response.statusCode}): ${response.body}');
        return const PerspectiveResult(isToxic: false, score: 0.0, attribute: 'TOXICITY');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final scores = data['attributeScores'] as Map<String, dynamic>? ?? {};

      double maxScore = 0.0;
      String maxAttr = 'TOXICITY';

      scores.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          final summary = value['summaryScore'] as Map<String, dynamic>?;
          final score = (summary?['value'] as num?)?.toDouble() ?? 0.0;
          if (score > maxScore) {
            maxScore = score;
            maxAttr = key;
          }
        }
      });

      return PerspectiveResult(
        isToxic: maxScore >= _toxicityThreshold,
        score: maxScore,
        attribute: maxAttr,
      );
    } catch (e) {
      debugPrint('PerspectiveService analyze exception: $e');
      return const PerspectiveResult(isToxic: false, score: 0.0, attribute: 'TOXICITY');
    }
  }
}
