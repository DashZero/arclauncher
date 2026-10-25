// Default values for the family TV launcher.
//
// This is the single place for keys and links. The owner decided they may live
// in this private repo; to move them out later, put this file in .gitignore and
// keep an example copy. Never print these values in logs.
const String kDefaultTmdbApiKey = '';
const String kDefaultGeminiApiKey = '';
const String kDefaultGeminiModel = 'gemini-2.5-flash';
const String kDefaultAlbumUrl = '';

/// Starting taste notes, editable in settings (AGENTS.md section 5).
const Map<String, String> kDefaultTasteProfiles = {
  'dad': 'Anime, especially isekai with comedy and food themes, and shonen action. Sci-fi and superheroes '
      '(Star Wars, Marvel, Spider-Man, Superman, Battlestar Galactica). Action series like Reacher. '
      'Sitcoms like How I Met Your Mother, Friends, The Big Bang Theory, The IT Crowd. Likes series.',
  'mom': 'Korean soaps and Chinese dramas.',
  'dadmom': 'Chinese fantasy and historical dramas (Fangs of Fortune, Pursuit of Jade, Keys to the Phoenix\'s Heart).',
  'kid': 'Age 7. Cartoons and kids\' shows (Doraemon, SpongeBob, Moana, Frozen).',
};

/// Titles that seed the movie-art wallpaper and the first recommendations.
const List<String> kDefaultSeedTitles = [
  'Reincarnated as a Slime',
  'Campfire Cooking in Another World',
  'The Eminence in Shadow',
  'One Piece',
  'Demon Slayer',
  'Jujutsu Kaisen',
  'Star Wars',
  'Reacher',
  'How I Met Your Mother',
  'Friends',
  'The Big Bang Theory',
  'The IT Crowd',
  'Fangs of Fortune',
  'Pursuit of Jade',
  'Doraemon',
  'Moana',
  'Frozen',
];

const String kDefaultDislikes = 'Horror and scary content.';
