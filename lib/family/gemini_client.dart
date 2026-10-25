import 'dart:convert';

import 'package:flauncher/family/family_settings.dart';
import 'package:http/http.dart' as http;

/// A title the AI suggested. It is only a candidate until TMDB resolves it.
class Candidate {
  final String title;
  final int? year;
  final String? type;
  final Person person;
  final String reason;

  const Candidate({required this.title, required this.year, required this.type, required this.person, required this.reason});
}

/// Parses and validates the model's JSON answer. Anything malformed is dropped;
/// returns null when the whole answer is unusable so the caller can retry once.
List<Candidate>? parseCandidates(String text) {
  try {
    var body = text.trim();
    if (body.startsWith('```')) {
      body = body.replaceAll(RegExp(r'^```(?:json)?'), '').replaceAll(RegExp(r'```$'), '').trim();
    }
    final decoded = jsonDecode(body);
    final list = decoded is Map ? decoded['recommendations'] : decoded;
    if (list is! List) return null;
    final out = <Candidate>[];
    for (final e in list) {
      if (e is! Map) continue;
      final title = (e['title'] as String?)?.trim();
      final person = e['person'] as String?;
      if (title == null || title.isEmpty || title.length > 120) continue;
      if (!Person.values.any((p) => p.key == person)) continue;
      final type = e['type'] as String?;
      out.add(Candidate(
        title: title,
        year: e['year'] is int ? e['year'] as int : int.tryParse('${e['year']}'),
        type: (type == 'tv' || type == 'movie') ? type : null,
        person: Person.fromKey(person),
        reason: ((e['reason'] as String?) ?? '').trim(),
      ));
    }
    return out.isEmpty ? null : out;
  } catch (_) {
    return null;
  }
}

/// Calls the Gemini API. The key goes only in the request header to Google and
/// is never logged. Only titles and taste text are sent.
class GeminiClient {
  final String apiKey;
  final String model;
  final http.Client _client;

  GeminiClient({required this.apiKey, required this.model, http.Client? client}) : _client = client ?? http.Client();

  bool get isConfigured => apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  /// Returns the model's raw text answer, or null on any failure.
  Future<String?> generate(String prompt) async {
    if (!isConfigured) return null;
    final uri = Uri.https('generativelanguage.googleapis.com', '/v1beta/models/$model:generateContent');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {'responseMimeType': 'application/json', 'temperature': 0.8},
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final parts = data['candidates']?[0]?['content']?['parts'] as List?;
      return parts?.map((p) => (p as Map)['text'] ?? '').join();
    } catch (_) {
      return null;
    }
  }
}

/// Builds the prompt from taste notes, not raw title lists, so answers are
/// similar titles rather than repeats.
String buildPrompt({
  required Map<Person, String> profiles,
  required String dislikes,
  required Map<Person, List<String>> liked,
  required Map<Person, List<String>> disliked,
  required List<String> recentlyWatching,
  int perPerson = 6,
}) {
  final b = StringBuffer()
    ..writeln('You recommend TV series, anime and movies for a family. Suggest titles that are SIMILAR to the taste notes, '
        'not the same titles listed. Prefer real, well-known titles. Answer with JSON only.')
    ..writeln('Return {"recommendations":[{"title":"","year":2020,"type":"tv|movie","person":"dad|mom|dadmom|kid","reason":"one short line"}]}.')
    ..writeln('Give $perPerson items for each person key. Never suggest horror or scary content for anyone.')
    ..writeln('Kid is 7 years old: only titles suitable for a young child (rated TV-Y, TV-Y7, G or PG). Do not treat "animated" as kid-safe.')
    ..writeln('Dislikes (everyone): $dislikes');
  for (final p in Person.values) {
    b.writeln('Taste notes for ${p.key}: ${profiles[p]}');
    final up = liked[p] ?? const [];
    final down = disliked[p] ?? const [];
    if (up.isNotEmpty) b.writeln('Liked by ${p.key}: ${up.join(', ')}');
    if (down.isNotEmpty) b.writeln('Disliked by ${p.key} (never suggest): ${down.join(', ')}');
  }
  if (recentlyWatching.isNotEmpty) {
    b.writeln('Recently watched on the TV (weak signal): ${recentlyWatching.take(15).join(', ')}');
  }
  return b.toString();
}
