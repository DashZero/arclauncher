import 'dart:io';
import 'dart:math';

import 'package:flauncher/family/family_defaults.dart';
import 'package:flauncher/family/tmdb_client.dart';
import 'package:flauncher/family/wallpaper_cache.dart';
import 'package:http/http.dart' as http;

/// Movie and show backdrops from TMDB as the home wallpaper. Each call downloads
/// one image into a small rolling cache with a hard size cap; the caller deletes
/// the previous file once the new one is on screen.
class MovieWallpaper {
  final Directory cacheDir;
  final http.Client _client;

  /// Backdrop paths per title, kept in memory so one title costs two requests, not one per image.
  final Map<String, List<String>> _pool = {};

  MovieWallpaper(this.cacheDir, {http.Client? client}) : _client = client ?? http.Client();

  /// [titles] are the taste-profile titles (seeds, liked titles, recommendations).
  /// Returns null when offline, unconfigured or nothing is found, so the caller keeps the current image.
  Future<File?> next({
    required String tmdbKey,
    required int width,
    required int capMb,
    required List<String> titles,
    Set<String> keep = const {},
    Random? random,
  }) async {
    final tmdb = TmdbClient(tmdbKey, client: _client);
    if (!tmdb.isConfigured) return null;
    final rnd = random ?? Random();
    final pool = titles.isNotEmpty ? titles : kDefaultSeedTitles;

    // A few attempts: the random title may have no usable backdrop.
    for (var attempt = 0; attempt < 4; attempt++) {
      final title = pool[rnd.nextInt(pool.length)];
      var paths = _pool[title];
      if (paths == null) {
        final found = await tmdb.findId(title);
        paths = found == null ? <String>[] : await tmdb.backdropsFor(found.type, found.id);
        _pool[title] = paths;
      }
      if (paths.isEmpty) continue;

      final path = paths[rnd.nextInt(paths.length)];
      try {
        final response = await _client.get(Uri.parse(TmdbClient.backdropUrl(path, width: width)));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) continue;

        await cacheDir.create(recursive: true);
        final name = path.replaceAll('/', '');
        final tmp = File('${cacheDir.path}/$name.part');
        await tmp.writeAsBytes(response.bodyBytes, flush: true);
        final file = await tmp.rename('${cacheDir.path}/$name');
        enforceCacheCap(cacheDir, capMb * 1024 * 1024, keep: {...keep, file.path});
        return file;
      } catch (_) {
        // Offline or interrupted download: try again next interval.
      }
    }
    return null;
  }
}
