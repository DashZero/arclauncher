# Gemini brief: recommendations row, detail card and taste profile editor compile and analyze clean

Route: model=gemini-3.8-flash-high · pool=owner's choice · effort=medium · tool=owner's Gemini CLI or gateway (this repo has no gateway script) · key=owner's env var
Scope: UI only, new files only. Do NOT touch any existing file (especially `lib/flauncher.dart`, `lib/providers/*`, `lib/family/family_settings.dart`, `lib/family/recommendation_models.dart`, `pubspec.yaml`, `android/`, `AGENTS.md`). Do NOT write any AI, TMDB, filtering or network code: Claude writes `RecommendationService`. If a change would need an existing file, STOP and write `NEEDS_DECISION: <question>`.
Read first: `AGENTS.md` sections 2, 3.2 and 5; `lib/family/recommendation_models.dart` and `lib/family/family_settings.dart` (whole files); `lib/widgets/settings/focusable_settings_tile.dart`; `lib/widgets/settings/settings_theme.dart`; `lib/widgets/watch_next_row.dart` (row layout and focus handling only).

## Problem
The home screen needs a "Recommended for you" row of info cards for a family TV. Data comes from `RecommendationFeed` (abstract class in `recommendation_models.dart`: `items`, `isRefreshing`, `refresh()`, `thumb(item, up)`). The row must be smooth with a D-pad on a slow Mi TV Box.

## Owner decisions (apply exactly)
- Info cards only. Pressing OK opens a detail card (a dialog). **Never launch any app.**
- Each card shows: poster (network image, with a plain placeholder box if null or on error), title, year, a one-line reason (max 2 lines, ellipsis), a person badge (`person.label`: Dad / Mom / Dad + Mom / Kid) and the provider names (or "Not listed" if the list is empty).
- Auto-scroll through badge groups **only while idle**: every 8 seconds scroll the row so the first card of the next person group is at the left edge. It must **stop as soon as any card in the row has focus** and not restart until focus leaves the row and 20 seconds pass. Cancel all timers in `dispose`.
- The detail card shows backdrop (if any), title and year, rating, providers, overview, and the reason, plus two buttons "Like" and "Not for us" that call `feed.thumb(item, true/false)` and close the dialog. D-pad focusable, back button closes.
- Performance first: no blur, no `BackdropFilter`, no big shadows. Use `Image.network` with `cacheWidth` set (about 300 for posters) so decoded images stay small. `ListView.builder` with `itemExtent`.
- English text only (no l10n files). Do not log titles, keys or any user data.

## What to build
1. `lib/family/ui/recommendations_row.dart`: `class RecommendationsRow extends StatefulWidget`. Reads `RecommendationFeed` via `context.watch<RecommendationFeed>()`. Header "Recommended for you" with a small "Refresh" focusable button that calls `refresh()` (shows "Refreshing..." while `isRefreshing`). Empty `items` while not refreshing: show the header and one line "No recommendations yet" (still focusable-free). Acceptance: analyze clean.
2. `lib/family/ui/recommendation_detail_dialog.dart`: `Future<void> showRecommendationDetail(BuildContext context, Recommendation item, RecommendationFeed feed)`.
3. `lib/family/ui/taste_profile_page.dart`: `class TasteProfilePage extends StatelessWidget` with `static const String routeName = "family_taste_profiles";`. Uses `SettingsPageHeader(title: 'Taste profiles')` and for each `Person` a `FocusableSettingsTile` showing the label and the first 60 characters of `FamilySettings.profile(person)`; selecting opens an `AlertDialog` with a multi-line `TextField` prefilled with the profile and Save and Cancel (Save calls `setProfile`). One more tile "Dislikes (everyone)" does the same with `dislikes`/`setDislikes`. A last tile "Refresh recommendations" calls `context.read<RecommendationFeed>().refresh()`.
4. `test/family/recommendations_row_test.dart`: widget tests with a fake `RecommendationFeed` (extend `ChangeNotifier`, implement the interface): (a) three items render their titles and badges; (b) empty list shows "No recommendations yet"; (c) selecting a card opens the detail dialog and no platform channel is called; (d) tapping "Like" calls `thumb(item, true)` once. Wrap images with `network_image_mock` (already a dev dependency). Each test must fail if the code it covers is removed (say how you checked).
Not in this job: wiring into the home screen or settings panel, the service, the Gemini or TMDB code, new l10n, native code, idle detection beyond the row's own focus (a `FocusScope` listener is enough).

## Gates (exact output pasted, never copied from another run)
`fvm dart format` on your files; `fvm flutter analyze` (no new issues); `fvm flutter test test/family/recommendations_row_test.dart`; `git diff --stat origin/main` must list only the four files above.

## Environment
`fvm flutter --version` must print 3.41.9 or STOP. Work in a new worktree on branch `gemini/recommendations-ui` from the branch Claude names in the paste prompt. Never touch the main clone.

## Handover
Commit in small steps; `git push -u origin gemini/recommendations-ui` as its own command; verify with `git rev-list --left-right --count origin/gemini/recommendations-ui...HEAD`. If the push fails, say so and paste the report in the chat. Write `handoff/outbox/recommendations-ui-report.md` (at most 40 lines: files, tests, exact gate output, deviations, NEEDS_DECISION lines). Write a 5-line checkpoint note there after the first working piece. Stop at the first blocker you cannot fix in two attempts. Do not merge. Never invent numbers.
