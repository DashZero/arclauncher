import 'dart:convert';

import 'package:http/http.dart' as http;

/// A title resolved through TMDB. All fields come from TMDB, never from the AI.
class TmdbTitle {
  /// "tv:123" or "movie:456".
  final String key;
  final String type;
  final String title;
  final int? year;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final double? rating;
  final List<String> genres;
  final List<int> genreIds;

  /// Age rating such as "TV-Y7" or "PG"; null when TMDB has none.
  final String? certification;

  /// Thailand flatrate streaming provider names.
  final List<String> providers;

  const TmdbTitle({
    required this.key,
    required this.type,
    required this.title,
    required this.year,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.rating,
    required this.genres,
    required this.genreIds,
    required this.certification,
    required this.providers,
  });
}

/// Minimal TMDB v3 client. The key is sent only to api.themoviedb.org and is
/// never logged. A key starting with "eyJ" is treated as a v4 read token.
class TmdbClient {
  static const _host = 'api.themoviedb.org';
  static const imageBase = 'https://image.tmdb.org/t/p/';

  final String apiKey;
  final http.Client _client;

  TmdbClient(this.apiKey, {http.Client? client}) : _client = client ?? http.Client();

  bool get isConfigured => apiKey.trim().isNotEmpty;

  static String posterUrl(String path, {int width = 342}) => '${imageBase}w$width$path';

  static String backdropUrl(String path, {int width = 1280}) {
    // TMDB serves backdrops at w300, w780, w1280 and original.
    final size = width <= 300 ? 300 : (width <= 780 ? 780 : 1280);
    return '${imageBase}w$size$path';
  }

  Future<Map<String, dynamic>?> _get(String path, Map<String, String> query) async {
    if (!isConfigured) return null;
    final bearer = apiKey.startsWith('eyJ');
    final uri = Uri.https(_host, '/3$path', {...query, if (!bearer) 'api_key': apiKey});
    try {
      final response = await _client
          .get(uri, headers: bearer ? {'Authorization': 'Bearer $apiKey'} : const {})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      // Offline or bad key: callers fall back to cache. Never print the URL, it holds the key.
      return null;
    }
  }

  /// Finds the best match for [title]. [type] is "tv", "movie" or null for either.
  Future<TmdbTitle?> resolve(String title, {int? year, String? type}) async {
    final search = await _get('/search/multi', {'query': title, 'include_adult': 'false'});
    final results = (search?['results'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
    final candidates =
        results.where((r) => r['media_type'] == 'tv' || r['media_type'] == 'movie').where((r) {
      return type == null || r['media_type'] == type;
    }).toList();
    if (candidates.isEmpty) return null;

    Map<String, dynamic> pick = candidates.first;
    if (year != null) {
      for (final c in candidates) {
        final y = _year(c);
        if (y != null && (y - year).abs() <= 1) {
          pick = c;
          break;
        }
      }
    }
    return details(pick['media_type'] as String, pick['id'] as int);
  }

  Future<TmdbTitle?> details(String type, int id) async {
    final append = type == 'tv' ? 'watch/providers,content_ratings' : 'watch/providers,release_dates';
    final d = await _get('/$type/$id', {'append_to_response': append});
    if (d == null) return null;

    final genresList = (d['genres'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
    final name = (type == 'tv' ? d['name'] : d['title']) as String?;
    if (name == null || name.isEmpty) return null;

    return TmdbTitle(
      key: '$type:$id',
      type: type,
      title: name,
      year: _year(d),
      overview: d['overview'] as String? ?? '',
      posterPath: d['poster_path'] as String?,
      backdropPath: d['backdrop_path'] as String?,
      rating: (d['vote_average'] as num?)?.toDouble(),
      genres: [for (final g in genresList) g['name'] as String? ?? ''],
      genreIds: [for (final g in genresList) g['id'] as int? ?? 0],
      certification: type == 'tv' ? _tvCertification(d) : _movieCertification(d),
      providers: _thaiProviders(d),
    );
  }

  /// Cheap lookup (one request) of the best TMDB match for [title].
  Future<({String type, int id})?> findId(String title) async {
    final search = await _get('/search/multi', {'query': title, 'include_adult': 'false'});
    final results = (search?['results'] as List?)?.whereType<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    for (final r in results) {
      if (r['media_type'] == 'tv' || r['media_type'] == 'movie') {
        return (type: r['media_type'] as String, id: r['id'] as int);
      }
    }
    return null;
  }

  /// Landscape backdrop paths for a title, for the wallpaper. Empty when nothing is found.
  Future<List<String>> backdropsFor(String type, int id) async {
    final d = await _get('/$type/$id/images', {'include_image_language': 'null'});
    final list = (d?['backdrops'] as List?)?.whereType<Map<String, dynamic>>() ?? const [];
    return [
      for (final b in list)
        if (b['file_path'] is String && ((b['width'] as int?) ?? 0) >= ((b['height'] as int?) ?? 1)) b['file_path'] as String
    ];
  }

  static int? _year(Map<String, dynamic> m) {
    final date = (m['release_date'] ?? m['first_air_date']) as String?;
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  static String? _tvCertification(Map<String, dynamic> d) {
    final results = (d['content_ratings']?['results'] as List?)?.whereType<Map<String, dynamic>>() ?? const [];
    for (final r in results) {
      if (r['iso_3166_1'] == 'US' && (r['rating'] as String?)?.isNotEmpty == true) return r['rating'] as String;
    }
    return null;
  }

  static String? _movieCertification(Map<String, dynamic> d) {
    final results = (d['release_dates']?['results'] as List?)?.whereType<Map<String, dynamic>>() ?? const [];
    for (final r in results) {
      if (r['iso_3166_1'] != 'US') continue;
      for (final rel in (r['release_dates'] as List?)?.whereType<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[]) {
        final c = rel['certification'] as String?;
        if (c != null && c.isNotEmpty) return c;
      }
    }
    return null;
  }

  static List<String> _thaiProviders(Map<String, dynamic> d) {
    final th = d['watch/providers']?['results']?['TH'];
    if (th is! Map<String, dynamic>) return const [];
    final flat = (th['flatrate'] as List?)?.whereType<Map<String, dynamic>>() ?? const [];
    return [for (final p in flat) p['provider_name'] as String? ?? ''].where((n) => n.isNotEmpty).toList();
  }
}
