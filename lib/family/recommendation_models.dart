import 'package:flauncher/family/family_settings.dart';
import 'package:flutter/foundation.dart';

/// One resolved recommendation shown on the home screen. Every field except
/// [reason] comes from TMDB, never from the AI, so the AI cannot invent it.
class Recommendation {
  /// TMDB key such as "tv:12345" or "movie:678".
  final String key;
  final String title;
  final int? year;
  final String type; // "tv" or "movie"
  final Person person;
  final String reason;
  final String? posterUrl;
  final String? backdropUrl;
  final String overview;
  final double? rating;

  /// Names of Thailand streaming providers, e.g. ["Netflix", "WeTV"]. Empty when TMDB has none.
  final List<String> providers;

  const Recommendation({
    required this.key,
    required this.title,
    required this.year,
    required this.type,
    required this.person,
    required this.reason,
    required this.posterUrl,
    required this.backdropUrl,
    required this.overview,
    required this.rating,
    required this.providers,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'year': year,
        'type': type,
        'person': person.key,
        'reason': reason,
        'poster': posterUrl,
        'backdrop': backdropUrl,
        'overview': overview,
        'rating': rating,
        'providers': providers,
      };

  factory Recommendation.fromJson(Map<String, dynamic> j) => Recommendation(
        key: j['key'] as String,
        title: j['title'] as String,
        year: j['year'] as int?,
        type: j['type'] as String? ?? 'tv',
        person: Person.fromKey(j['person'] as String?),
        reason: j['reason'] as String? ?? '',
        posterUrl: j['poster'] as String?,
        backdropUrl: j['backdrop'] as String?,
        overview: j['overview'] as String? ?? '',
        rating: (j['rating'] as num?)?.toDouble(),
        providers: List<String>.from(j['providers'] as List? ?? const []),
      );
}

/// What the recommendations row widgets need from the service. The real
/// implementation is `RecommendationService`; widgets depend only on this.
abstract class RecommendationFeed extends ChangeNotifier {
  /// Cached recommendations, already filtered and grouped by person. Never empty-throws; may be empty.
  List<Recommendation> get items;

  bool get isRefreshing;

  /// Starts a refresh in the background. Safe to call at any time.
  Future<void> refresh();

  /// Records a thumbs up or down for [item] and updates that person's profile.
  Future<void> thumb(Recommendation item, bool up);
}
