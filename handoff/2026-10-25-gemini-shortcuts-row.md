# Gemini brief: settings shortcut tiles row and its chooser page compile and analyze clean

Route: model=gemini-3.8-flash-high · pool=owner's choice · effort=medium · tool=owner's Gemini CLI or gateway (this repo has no gateway script) · key=owner's env var
Scope: UI only, new files only. Do NOT touch any existing file (especially `lib/flauncher.dart`, `lib/widgets/settings/settings_panel.dart`, `lib/providers/*`, `android/`, `pubspec.yaml`, `AGENTS.md`). Claude wires the new widgets in afterwards. If a change would need an existing file, STOP and write `NEEDS_DECISION: <question>`.
Read first: `AGENTS.md` sections 2 and 3.3; `lib/family/family_settings.dart` (whole file); `lib/widgets/settings/focusable_settings_tile.dart`; `lib/widgets/settings/rounded_switch_list_tile.dart`; `lib/widgets/settings/settings_theme.dart`; `lib/widgets/app_card.dart` (focus look only).

## Problem
The home screen needs a row of configurable shortcut tiles (Wi-Fi, Display, Storage, Apps, Bluetooth, Inputs, Play Store, Settings) that open Android settings. The owner picks which tiles show. Navigation must stay smooth on a slow TV box (Mi TV Box 2nd gen) using a D-pad.

## Owner decisions (apply exactly)
- Data is already defined in `lib/family/family_settings.dart`: `kShortcutDefs`, `kDefaultShortcutIds`, `FamilySettings.shortcutIds`, `setShortcutIds`, `showShortcuts`, `setShowShortcuts`. Use them; do not redefine.
- Launch with `FLauncherChannel().launchActivityFromAction(def.action!)` for an action, or `FLauncherChannel().launchApp(def.packageName!)` for a package (both in `lib/flauncher_channel.dart`). The call may do nothing on a box that lacks the screen; never throw or show an error dialog.
- Performance first: no blur, no `BackdropFilter`, no shadows with large blur radius, no per-frame animation. A simple border colour change on focus is enough.
- English text only (no l10n files).

## What to build
1. `lib/family/ui/shortcuts_row.dart`: `class ShortcutsRow extends StatelessWidget`. Reads `FamilySettings` with `context.watch`. Returns `SizedBox.shrink()` when `showShortcuts` is false or the list is empty. Otherwise a horizontal row of tiles (about 150x80 logical px, icon plus label), in the order of `shortcutIds`, ignoring unknown ids. Left padding 40. Each tile is focusable with D-pad (`Focus` plus `Shortcuts`/`Actions` for Enter and Select, or `InkWell`), shows a 2 px white border when focused and a faint border otherwise, and calls the launch above on select. Acceptance: `fvm flutter analyze` has no issues in this file.
2. `lib/family/ui/shortcuts_settings_page.dart`: `class ShortcutsSettingsPage extends StatelessWidget` with `static const String routeName = "family_shortcuts";`. Uses `SettingsPageHeader(title: 'Shortcut tiles')` (from `settings_theme.dart`), then one `RoundedSwitchListTile` for "Show shortcut tiles" (`showShortcuts`), then one `RoundedSwitchListTile` per entry of `kShortcutDefs` that turns that id on or off in `shortcutIds` (keep the existing order, append new ones at the end). Acceptance: analyze clean; toggling writes through `FamilySettings.setShortcutIds`.
3. `test/family/shortcuts_row_test.dart`: widget tests with `SharedPreferences.setMockInitialValues({})` and a `ChangeNotifierProvider<FamilySettings>`: (a) default settings show six tiles with the labels of `kDefaultShortcutIds`; (b) with `showShortcuts` false nothing renders; (c) an unknown id in `shortcutIds` is skipped without error. Do not test the channel call. Each test must fail if you comment out the code it covers (say how you checked).
Not in this job: wiring into the home screen or settings panel, new l10n strings, native Android code, any other settings.

## Gates (exact output pasted, never copied from another run)
`fvm dart format` on your files; `fvm flutter analyze` (no new issues); `fvm flutter test test/family/shortcuts_row_test.dart`; `git diff --stat origin/main` must list only the three files above.

## Environment
`fvm flutter --version` must print 3.41.9 or STOP. Work in a new worktree on branch `gemini/shortcuts-row` from the branch Claude names in the paste prompt. Never touch the main clone.

## Handover
Commit in small steps; `git push -u origin gemini/shortcuts-row` as its own command; verify with `git rev-list --left-right --count origin/gemini/shortcuts-row...HEAD`. If the push fails, say so and paste the report in the chat. Write `handoff/outbox/shortcuts-row-report.md` (at most 40 lines: files, tests, exact gate output, deviations, NEEDS_DECISION lines). Stop at the first blocker you cannot fix in two attempts. Do not merge. Never invent numbers.
