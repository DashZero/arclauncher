import 'package:flauncher/family/family_settings.dart';
import 'package:flauncher/family/tmdb_client.dart';

/// Safety nets applied after TMDB resolves a title, on top of the prompt
/// (AGENTS.md section 5). The AI's own judgement is never trusted for these.

/// Ratings allowed in the Kid row: TV-Y, TV-Y7, G, at most PG. TV-PG is left out
/// on purpose, and a missing rating is rejected (fail closed).
const Set<String> kKidAllowedRatings = {'TV-Y', 'TV-Y7', 'TV-Y7-FV', 'TV-G', 'G', 'PG'};

const int _movieHorrorGenreId = 27;

bool isHorror(TmdbTitle t) {
  if (t.genreIds.contains(_movieHorrorGenreId)) return true;
  if (t.genres.any((g) => g.toLowerCase().contains('horror'))) return true;
  // TMDB's TV genre list has no horror genre, so also look at the overview.
  final text = '${t.title} ${t.overview}'.toLowerCase();
  return RegExp(r'\b(horror|slasher|haunted|demonic possession|gore)\b').hasMatch(text);
}

bool isKidSafe(TmdbTitle t) {
  final rating = t.certification?.trim().toUpperCase();
  if (rating == null || rating.isEmpty) return false;
  return kKidAllowedRatings.contains(rating);
}

/// True when [t] may be shown in [person]'s group.
bool passesFilters(TmdbTitle t, Person person) {
  if (isHorror(t)) return false;
  if (person == Person.kid && !isKidSafe(t)) return false;
  return true;
}
