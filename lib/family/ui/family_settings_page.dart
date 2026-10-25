import 'package:flauncher/family/family_settings.dart';
import 'package:flauncher/family/recommendation_models.dart';
import 'package:flauncher/family/ui/setup_page.dart';
import 'package:flauncher/family/ui/shortcuts_settings_page.dart';
import 'package:flauncher/family/ui/taste_profile_page.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const List<int> _minuteChoices = [1, 5, 10, 30, 60];
const List<int> _capChoices = [10, 25, 50, 100];

T _next<T>(List<T> choices, T current) {
  final i = choices.indexOf(current);
  return choices[(i + 1) % choices.length];
}

/// Entry page for the family features: wallpaper, recommendations, shortcuts, phone setup.
class FamilySettingsPage extends StatelessWidget {
  static const String routeName = "family_settings";

  const FamilySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<FamilySettings>();
    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      children: [
        const SettingsPageHeader(title: 'Family'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              FocusableSettingsTile(
                autofocus: true,
                showChevron: true,
                leading: const Icon(Icons.qr_code_2),
                title: Text('Phone setup (QR)', style: style),
                subtitle: const Text('Album link, Gemini and TMDB keys'),
                onPressed: () => Navigator.of(context).pushNamed(FamilySetupPage.routeName),
              ),
              const SettingsSectionDivider(),
              RoundedSwitchListTile(
                value: s.movieWallpaperEnabled,
                onChanged: s.setMovieWallpaperEnabled,
                title: Text('Family wallpaper', style: style),
                subtitle: const Text('Turns off when you pick a wallpaper by hand'),
                secondary: const Icon(Icons.movie_outlined),
              ),
              FocusableSettingsTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text('Wallpaper source', style: style),
                subtitle: Text(s.wallpaperSource == 'photos' ? 'Google Photos album' : 'Movie and show art (TMDB)'),
                onPressed: () => s.setWallpaperSource(s.wallpaperSource == 'photos' ? 'movies' : 'photos'),
              ),
              FocusableSettingsTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('Change every', style: style),
                subtitle: Text('${s.wallpaperMinutes} min'),
                onPressed: () => s.setWallpaperMinutes(_next(_minuteChoices, s.wallpaperMinutes)),
              ),
              FocusableSettingsTile(
                leading: const Icon(Icons.sd_storage_outlined),
                title: Text('Wallpaper cache limit', style: style),
                subtitle: Text('${s.cacheCapMb} MB'),
                onPressed: () => s.setCacheCapMb(_next(_capChoices, s.cacheCapMb)),
              ),
              RoundedSwitchListTile(
                value: s.followFocusWallpaper,
                onChanged: s.setFollowFocusWallpaper,
                title: Text('Follow the highlighted title', style: style),
                subtitle: const Text('Uses more data and may slow a weak box'),
                secondary: const Icon(Icons.center_focus_strong_outlined),
              ),
              const SettingsSectionDivider(),
              RoundedSwitchListTile(
                value: s.showRecommendations,
                onChanged: s.setShowRecommendations,
                title: Text('Recommended for you row', style: style),
                secondary: const Icon(Icons.recommend_outlined),
              ),
              FocusableSettingsTile(
                showChevron: true,
                leading: const Icon(Icons.people_outline),
                title: Text('Taste profiles', style: style),
                onPressed: () => Navigator.of(context).pushNamed(TasteProfilePage.routeName),
              ),
              FocusableSettingsTile(
                leading: const Icon(Icons.refresh),
                title: Text('Refresh recommendations', style: style),
                onPressed: () => context.read<RecommendationFeed>().refresh(),
              ),
              const SettingsSectionDivider(),
              FocusableSettingsTile(
                showChevron: true,
                leading: const Icon(Icons.apps_outlined),
                title: Text('Shortcut tiles', style: style),
                onPressed: () => Navigator.of(context).pushNamed(ShortcutsSettingsPage.routeName),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
