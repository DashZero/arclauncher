import 'dart:async';
import 'dart:convert';

import 'package:flauncher/family/family_settings.dart';
import 'package:flauncher/family/gemini_client.dart';
import 'package:flauncher/family/recommendation_filters.dart';
import 'package:flauncher/family/recommendation_models.dart';
import 'package:flauncher/family/tmdb_client.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _cacheKey = 'family_recs_cache';
const _cacheTimeKey = 'family_recs_time';

/// Gemini plus TMDB pipeline behind the "Recommended for you" row. It always
/// serves the cached list; refreshing happens in the background.
class RecommendationService extends RecommendationFeed {
  final FamilySettings _settings;
  final SharedPreferences _prefs;
  final http.Client? _client;
  final List<String> Function() _watchNextTitles;

  static const Duration refreshEvery = Duration(hours: 24);

  List<Recommendation> _items = [];
  bool _refreshing = false;
  Timer? _startupTimer;

  RecommendationService(
    this._settings,
    this._prefs, {
    http.Client? client,
    List<String> Function()? watchNextTitles,
    bool autoRefresh = true,
  })  : _client = client,
        _watchNextTitles = watchNextTitles ?? (() => const []) {
    _items = _readCache();
    // Daily refresh, started shortly after launch so it never competes with startup.
    if (autoRefresh) _startupTimer = Timer(const Duration(minutes: 2), _refreshIfDue);
  }

  @override
  List<Recommendation> get items => List.unmodifiable(_items);

  @override
  bool get isRefreshing => _refreshing;

  @override
  void dispose() {
    _startupTimer?.cancel();
    super.dispose();
  }

  DateTime? get lastRefresh {
    final ms = _prefs.getInt(_cacheTimeKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _refreshIfDue() async {
    final last = lastRefresh;
    if (last == null || DateTime.now().difference(last) >= refreshEvery) await refresh();
  }

  List<Recommendation> _readCache() {
    try {
      final raw = _prefs.getString(_cacheKey);
      if (raw == null) return [];
      return [for (final j in jsonDecode(raw) as List) Recommendation.fromJson(j as Map<String, dynamic>)];
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeCache() async {
    await _prefs.setString(_cacheKey, jsonEncode([for (final r in _items) r.toJson()]));
    await _prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Future<void> refresh() async {
    if (_refreshing) return;
    final tmdb = TmdbClient(_settings.tmdbKey, client: _client);
    final gemini = GeminiClient(apiKey: _settings.geminiKey, model: _settings.geminiModel, client: _client);
    if (!tmdb.isConfigured || !gemini.isConfigured) return; // Offline-safe: keep the cache.

    _refreshing = true;
    notifyListeners();
    try {
      final candidates = await _askGemini(gemini);
      if (candidates == null) return;
      final resolved = await _resolve(tmdb, candidates);
      if (resolved.isNotEmpty) {
        _items = resolved;
        await _writeCache();
      }
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<List<Candidate>?> _askGemini(GeminiClient gemini) async {
    final thumbs = _settings.thumbs;
    Map<Person, List<String>> byPerson(bool up) => {
          for (final p in Person.values)
            p: [
              for (final e in thumbs.values)
                if (e['person'] == p.key && e['up'] == up) e['title'] as String
            ]
        };
    final prompt = buildPrompt(
      profiles: {for (final p in Person.values) p: _settings.profile(p)},
      dislikes: _settings.dislikes,
      liked: byPerson(true),
      disliked: byPerson(false),
      recentlyWatching: _watchNextTitles(),
    );
    // Retry once on an unusable answer.
    for (var attempt = 0; attempt < 2; attempt++) {
      final text = await gemini.generate(prompt);
      if (text == null) continue;
      final parsed = parseCandidates(text);
      if (parsed != null) return parsed;
    }
    return null;
  }

  Future<List<Recommendation>> _resolve(TmdbClient tmdb, List<Candidate> candidates) async {
    final thumbs = _settings.thumbs;
    final liked = {for (final e in thumbs.entries) if (e.value['up'] == true) e.key};
    final blocked = {for (final e in thumbs.entries) if (e.value['up'] == false) e.key};
    final seen = <String>{};
    final out = <Recommendation>[];

    for (final c in candidates) {
      final t = await tmdb.resolve(c.title, year: c.year, type: c.type);
      if (t == null) continue; // The AI may invent titles; TMDB must know it.
      if (!passesFilters(t, c.person)) continue;
      if (blocked.contains(t.key) || liked.contains(t.key)) continue;
      if (!seen.add('${c.person.key}|${t.key}')) continue;
      out.add(Recommendation(
        key: t.key,
        title: t.title,
        year: t.year,
        type: t.type,
        person: c.person,
        reason: c.reason,
        posterUrl: t.posterPath == null ? null : TmdbClient.posterUrl(t.posterPath!),
        backdropUrl: t.backdropPath == null ? null : TmdbClient.backdropUrl(t.backdropPath!),
        overview: t.overview,
        rating: t.rating,
        providers: t.providers,
      ));
    }
    out.sort((a, b) => a.person.index.compareTo(b.person.index));
    return out;
  }

  @override
  Future<void> thumb(Recommendation item, bool up) async {
    await _settings.setThumb(item.key, item.person, item.title, up);
    // Thumbs feed the next prompt. A thumbs up or down also removes the card.
    _items = [
      for (final r in _items)
        if (!(r.key == item.key && r.person == item.person)) r
    ];
    await _writeCache();
    notifyListeners();
  }
}
