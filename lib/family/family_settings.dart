import 'dart:convert';

import 'package:flauncher/family/family_defaults.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// People the recommendations are tagged for.
enum Person {
  dad('dad', 'Dad'),
  mom('mom', 'Mom'),
  dadMom('dadmom', 'Dad + Mom'),
  kid('kid', 'Kid');

  final String key;
  final String label;

  const Person(this.key, this.label);

  static Person fromKey(String? key) => Person.values.firstWhere((p) => p.key == key, orElse: () => Person.dad);
}

/// A settings shortcut tile the owner can show on the home screen.
class ShortcutDef {
  final String id;
  final String label;

  /// Android intent action, or null when [packageName] is launched instead.
  final String? action;
  final String? packageName;

  const ShortcutDef(this.id, this.label, {this.action, this.packageName});
}

const List<ShortcutDef> kShortcutDefs = [
  ShortcutDef('wifi', 'Wi-Fi', action: 'android.settings.WIFI_SETTINGS'),
  ShortcutDef('display', 'Display', action: 'android.settings.DISPLAY_SETTINGS'),
  ShortcutDef('storage', 'Storage', action: 'android.settings.INTERNAL_STORAGE_SETTINGS'),
  ShortcutDef('apps', 'Apps', action: 'android.settings.APPLICATION_SETTINGS'),
  ShortcutDef('bluetooth', 'Bluetooth', action: 'android.settings.BLUETOOTH_SETTINGS'),
  ShortcutDef('inputs', 'Inputs', action: 'android.settings.INPUT_METHOD_SETTINGS'),
  ShortcutDef('play', 'Play Store', packageName: 'com.android.vending'),
  ShortcutDef('settings', 'Settings', action: 'android.settings.SETTINGS'),
];

const List<String> kDefaultShortcutIds = ['wifi', 'display', 'storage', 'apps', 'bluetooth', 'settings'];

/// Settings that belong to the family features. Kept apart from Arc's
/// [SettingsService] so upstream changes stay mergeable.
class FamilySettings extends ChangeNotifier {
  final SharedPreferences _prefs;

  FamilySettings(this._prefs);

  static const _tmdbKey = 'family_tmdb_key';
  static const _geminiKey = 'family_gemini_key';
  static const _geminiModel = 'family_gemini_model';
  static const _albumUrl = 'family_album_url';
  static const _movieWallpaper = 'family_movie_wallpaper';
  static const _wallpaperSource = 'family_wallpaper_source';
  static const _wallpaperMinutes = 'family_wallpaper_minutes';
  static const _wallpaperWidth = 'family_wallpaper_width';
  static const _cacheCapMb = 'family_cache_cap_mb';
  static const _followFocus = 'family_follow_focus';
  static const _shortcutIds = 'family_shortcut_ids';
  static const _showShortcuts = 'family_show_shortcuts';
  static const _showRecs = 'family_show_recs';
  static const _profilePrefix = 'family_profile_';
  static const _dislikes = 'family_dislikes';
  static const _thumbs = 'family_thumbs';

  String get tmdbKey => _prefs.getString(_tmdbKey) ?? kDefaultTmdbApiKey;
  String get geminiKey => _prefs.getString(_geminiKey) ?? kDefaultGeminiApiKey;
  String get geminiModel => _prefs.getString(_geminiModel) ?? kDefaultGeminiModel;
  String get albumUrl => _prefs.getString(_albumUrl) ?? kDefaultAlbumUrl;

  /// Wallpaper source: "movies" (default) or "photos".
  String get wallpaperSource => _prefs.getString(_wallpaperSource) ?? 'movies';

  bool get movieWallpaperEnabled => _prefs.getBool(_movieWallpaper) ?? true;
  int get wallpaperMinutes => _prefs.getInt(_wallpaperMinutes) ?? 1;
  int get wallpaperWidth => _prefs.getInt(_wallpaperWidth) ?? 1280;
  int get cacheCapMb => _prefs.getInt(_cacheCapMb) ?? 25;
  bool get followFocusWallpaper => _prefs.getBool(_followFocus) ?? false;

  bool get showShortcuts => _prefs.getBool(_showShortcuts) ?? true;
  bool get showRecommendations => _prefs.getBool(_showRecs) ?? true;

  List<String> get shortcutIds => _prefs.getStringList(_shortcutIds) ?? kDefaultShortcutIds;

  String profile(Person person) => _prefs.getString('$_profilePrefix${person.key}') ?? kDefaultTasteProfiles[person.key]!;
  String get dislikes => _prefs.getString(_dislikes) ?? kDefaultDislikes;

  /// Thumbs history: tmdb key ("tv:123") to {"person": ..., "title": ..., "up": bool}.
  Map<String, Map<String, dynamic>> get thumbs {
    final raw = _prefs.getString(_thumbs);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
    } catch (_) {
      return {};
    }
  }

  Future<void> _notify(Future<bool> write) async {
    await write;
    notifyListeners();
  }

  Future<void> setTmdbKey(String v) => _notify(_prefs.setString(_tmdbKey, v.trim()));
  Future<void> setGeminiKey(String v) => _notify(_prefs.setString(_geminiKey, v.trim()));
  Future<void> setGeminiModel(String v) => _notify(_prefs.setString(_geminiModel, v.trim()));
  Future<void> setAlbumUrl(String v) => _notify(_prefs.setString(_albumUrl, v.trim()));
  Future<void> setWallpaperSource(String v) => _notify(_prefs.setString(_wallpaperSource, v));
  Future<void> setMovieWallpaperEnabled(bool v) => _notify(_prefs.setBool(_movieWallpaper, v));
  Future<void> setWallpaperMinutes(int v) => _notify(_prefs.setInt(_wallpaperMinutes, v.clamp(1, 1440)));
  Future<void> setWallpaperWidth(int v) => _notify(_prefs.setInt(_wallpaperWidth, v));
  Future<void> setCacheCapMb(int v) => _notify(_prefs.setInt(_cacheCapMb, v.clamp(5, 200)));
  Future<void> setFollowFocusWallpaper(bool v) => _notify(_prefs.setBool(_followFocus, v));
  Future<void> setShowShortcuts(bool v) => _notify(_prefs.setBool(_showShortcuts, v));
  Future<void> setShowRecommendations(bool v) => _notify(_prefs.setBool(_showRecs, v));
  Future<void> setShortcutIds(List<String> v) => _notify(_prefs.setStringList(_shortcutIds, v));
  Future<void> setProfile(Person p, String v) => _notify(_prefs.setString('$_profilePrefix${p.key}', v));
  Future<void> setDislikes(String v) => _notify(_prefs.setString(_dislikes, v));

  Future<void> setThumb(String tmdbKey, Person person, String title, bool up) {
    final all = thumbs;
    all[tmdbKey] = {'person': person.key, 'title': title, 'up': up};
    return _notify(_prefs.setString(_thumbs, jsonEncode(all)));
  }

  /// Applies a batch of values posted from the phone setup page.
  Future<void> applySetup(Map<String, String> values) async {
    if (values['album']?.isNotEmpty ?? false) await _prefs.setString(_albumUrl, values['album']!.trim());
    if (values['gemini_key']?.isNotEmpty ?? false) await _prefs.setString(_geminiKey, values['gemini_key']!.trim());
    if (values['gemini_model']?.isNotEmpty ?? false) {
      await _prefs.setString(_geminiModel, values['gemini_model']!.trim());
    }
    if (values['tmdb_key']?.isNotEmpty ?? false) await _prefs.setString(_tmdbKey, values['tmdb_key']!.trim());
    notifyListeners();
  }
}
