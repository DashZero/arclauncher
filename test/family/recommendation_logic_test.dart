import 'dart:convert';

import 'package:flauncher/family/family_settings.dart';
import 'package:flauncher/family/gemini_client.dart';
import 'package:flauncher/family/recommendation_filters.dart';
import 'package:flauncher/family/recommendation_service.dart';
import 'package:flauncher/family/tmdb_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

TmdbTitle title({String? cert, List<int> genreIds = const [], List<String> genres = const [], String overview = ''}) =>
    TmdbTitle(
      key: 'tv:1',
      type: 'tv',
      title: 'X',
      year: 2020,
      overview: overview,
      posterPath: null,
      backdropPath: null,
      rating: 7,
      genres: genres,
      genreIds: genreIds,
      certification: cert,
      providers: const [],
    );

void main() {
  group('filters', () {
    test('kid row allows only TV-Y, TV-Y7, TV-G, G and PG', () {
      for (final ok in ['TV-Y', 'TV-Y7', 'TV-G', 'G', 'PG']) {
        expect(passesFilters(title(cert: ok), Person.kid), isTrue, reason: ok);
      }
      for (final bad in ['TV-PG', 'TV-14', 'TV-MA', 'PG-13', 'R']) {
        expect(passesFilters(title(cert: bad), Person.kid), isFalse, reason: bad);
      }
    });

    test('kid row rejects a title with no rating', () {
      expect(passesFilters(title(cert: null), Person.kid), isFalse);
    });

    test('horror is filtered for everyone by genre and by overview', () {
      for (final p in Person.values) {
        expect(passesFilters(title(cert: 'G', genreIds: [27]), p), isFalse);
        expect(passesFilters(title(cert: 'G', genres: ['Horror']), p), isFalse);
        expect(passesFilters(title(cert: 'G', overview: 'A haunted house story'), p), isFalse);
      }
    });

    test('adults are not limited by age rating', () {
      expect(passesFilters(title(cert: 'TV-MA'), Person.dad), isTrue);
    });
  });

  group('parseCandidates', () {
    test('accepts a valid answer and drops malformed entries', () {
      final out = parseCandidates(jsonEncode({
        'recommendations': [
          {'title': 'Frieren', 'year': 2023, 'type': 'tv', 'person': 'dad', 'reason': 'fantasy'},
          {'title': '', 'person': 'dad'},
          {'title': 'Nobody', 'person': 'cat'},
        ]
      }))!;
      expect(out.map((c) => c.title), ['Frieren']);
    });

    test('returns null for unusable text so the caller can retry', () {
      expect(parseCandidates('not json'), isNull);
      expect(parseCandidates('{"recommendations": 3}'), isNull);
    });
  });

  group('RecommendationService', () {
    Future<(FamilySettings, SharedPreferences)> setup() async {
      SharedPreferences.setMockInitialValues({'family_tmdb_key': 'tmdb', 'family_gemini_key': 'gem'});
      final prefs = await SharedPreferences.getInstance();
      return (FamilySettings(prefs), prefs);
    }

    http.Client fakeApis(Map<String, Map<String, dynamic>> tmdbByQuery, List<Map<String, dynamic>> recs,
        {List<int>? geminiCalls}) {
      return MockClient((req) async {
        if (req.url.host == 'generativelanguage.googleapis.com') {
          geminiCalls?.add(1);
          return http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': jsonEncode({'recommendations': recs})}
                      ]
                    }
                  }
                ]
              }),
              200);
        }
        final path = req.url.path;
        if (path.endsWith('/search/multi')) {
          final hit = tmdbByQuery[req.url.queryParameters['query']];
          return http.Response(
              jsonEncode({
                'results': hit == null
                    ? []
                    : [
                        {'media_type': 'tv', 'id': hit['id'], 'first_air_date': '2020-01-01'}
                      ]
              }),
              200);
        }
        final id = int.parse(path.split('/').last);
        final hit = tmdbByQuery.values.firstWhere((h) => h['id'] == id);
        return http.Response(jsonEncode(hit['details']), 200);
      });
    }

    Map<String, dynamic> hit(int id, String name, {String? cert, List<Map<String, dynamic>> genres = const []}) => {
          'id': id,
          'details': {
            'name': name,
            'first_air_date': '2020-01-01',
            'overview': 'o',
            'vote_average': 7.5,
            'genres': genres,
            'content_ratings': {
              'results': cert == null
                  ? []
                  : [
                      {'iso_3166_1': 'US', 'rating': cert}
                    ]
            },
            'watch/providers': {
              'results': {
                'TH': {
                  'flatrate': [
                    {'provider_name': 'Netflix'}
                  ]
                }
              }
            },
          },
        };

    test('drops titles TMDB cannot resolve, horror, and unsafe kid titles', () async {
      final (settings, prefs) = await setup();
      final client = fakeApis({
        'Good Show': hit(1, 'Good Show', cert: 'TV-MA'),
        'Scary': hit(2, 'Scary', cert: 'TV-MA', genres: [
          {'id': 27, 'name': 'Horror'}
        ]),
        'Dark Anime': hit(3, 'Dark Anime', cert: 'TV-MA'),
        'Cartoon': hit(4, 'Cartoon', cert: 'TV-Y7'),
      }, [
        {'title': 'Good Show', 'type': 'tv', 'person': 'dad', 'reason': 'r'},
        {'title': 'Invented', 'type': 'tv', 'person': 'dad', 'reason': 'r'},
        {'title': 'Scary', 'type': 'tv', 'person': 'mom', 'reason': 'r'},
        {'title': 'Dark Anime', 'type': 'tv', 'person': 'kid', 'reason': 'r'},
        {'title': 'Cartoon', 'type': 'tv', 'person': 'kid', 'reason': 'r'},
      ]);
      final service = RecommendationService(settings, prefs, client: client, autoRefresh: false);

      await service.refresh();

      expect(service.items.map((r) => r.title), ['Good Show', 'Cartoon']);
      expect(service.items.first.providers, ['Netflix']);
      // The result is cached for offline starts.
      expect(RecommendationService(settings, prefs, client: client, autoRefresh: false).items.length, 2);
    });

    test('does nothing and keeps the cache when keys are missing', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final calls = <int>[];
      final service = RecommendationService(FamilySettings(prefs), prefs,
          client: fakeApis({}, [], geminiCalls: calls), autoRefresh: false);

      await service.refresh();

      expect(calls, isEmpty);
      expect(service.items, isEmpty);
    });

    test('a thumbs down removes the card and is never recommended again', () async {
      final (settings, prefs) = await setup();
      final client = fakeApis({'Good Show': hit(1, 'Good Show', cert: 'TV-MA')}, [
        {'title': 'Good Show', 'type': 'tv', 'person': 'dad', 'reason': 'r'},
      ]);
      final service = RecommendationService(settings, prefs, client: client, autoRefresh: false);
      await service.refresh();
      expect(service.items, hasLength(1));

      await service.thumb(service.items.first, false);
      expect(service.items, isEmpty);

      await service.refresh();
      expect(service.items, isEmpty);
    });
  });
}
