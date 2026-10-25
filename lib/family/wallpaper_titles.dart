import 'package:flauncher/family/family_defaults.dart';
import 'package:flauncher/family/family_settings.dart';
import 'package:flauncher/family/recommendation_models.dart';

/// Titles the movie-art wallpaper draws from: the seed list, titles somebody
/// liked, and the current recommendations except the Kid group.
List<String> familyWallpaperTitles(FamilySettings settings, List<Recommendation> recs) {
  final titles = <String>{...kDefaultSeedTitles};
  for (final e in settings.thumbs.values) {
    if (e['up'] == true && e['title'] is String) titles.add(e['title'] as String);
  }
  for (final r in recs) {
    if (r.person != Person.kid) titles.add(r.title);
  }
  return titles.toList();
}
