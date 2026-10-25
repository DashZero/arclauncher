# AGENTS.md: Family TV Launcher (fork of Arc Launcher)

This file is for AI coding agents. Read it fully before touching any code.

## 0. How to work (read first)

1. **Inspect the repo before proposing anything.** Read `README.md`, `pubspec.yaml`, `.fvmrc`, `lib/`, `android/`, `drift_schemas/`, and `CHANGELOG.md`. Find out how the wallpaper, settings, home rows, Watch Next, and screensaver code is structured.
2. **Write a short plan and wait for approval** before the first code change. The owner decided on 2026-10-25 that this app is small enough to build in **one pass** instead of phase by phase; the phases in section 6 now only describe the order of the TV tests. Say clearly what the owner must test on the TV.
3. **Never remove existing Arc features.** If a feature is heavy, make it a settings toggle and set its default (see section 4).
4. **Keep changes small and isolated.** Prefer new files and services over rewriting Arc internals, so upstream changes stay mergeable.
5. **Ask when unsure** instead of guessing, especially about Home button behavior and anything that changes existing Arc UX.
6. The owner cannot run most things for you. Say clearly what you could not test, and what the owner should test on the TV.

## 1. Project summary

A custom Android TV / Google TV launcher for one family's TV, built by forking **Arc Launcher** (https://github.com/meddouribadis/arclauncher).

- Arc is a fork of LTvLauncher, which is a fork of FLauncher. Flutter/Dart, GPL-3.0.
- This repo is **private and for home use only**. Keep GPL-3.0 license files intact.
- Target device: **Xiaomi Mi TV Box (2nd gen), 4K output**. It is **slow at times, with limited storage (counted in MB, not GB)**. Verify the real Android version and RAM with `adb shell` before assuming anything.
- The TV has these streaming apps: iQIYI, Netflix, Crunchyroll, Disney+, WeTV. Some services (for example Disney+, HBO) may not be installed, so **recommendations never launch apps**.
- Users: the owner (Dad), his wife (Mom), and a 7-year-old daughter (Kid).

## 2. Hard constraints

- **Performance first.** Smooth remote navigation matters more than any visual effect.
- **Storage is tight.** Every cache has a hard size cap and automatic cleanup.
- **Do not break the Google Photos system screensaver** (Google TV Ambient mode). It is a system feature that should keep working after the launcher is installed.
- **Home button:** Google TV can block replacing the default launcher. Investigate what Arc/LTvLauncher already provide (the README mentions Button Mapper remapping, disabling the stock launcher through ADB, and LTvLauncher's accessibility-service "Home Button Fix"). Reuse that; do not invent a new approach without asking.
- **Secrets:** the owner has decided that default values (album link, API keys) may live in a config file in this private repo. Still: never print keys in logs, never send them anywhere except their own API, and keep the file path in one place so it can be moved to `.gitignore` later.
- **Network:** all network work happens in the background and only when the user is idle. Handle offline gracefully; the home screen must always load from cache.

## 3. Features to build

### 3.1 Wallpaper (default: movie art)
- **Default source: TMDB backdrops** for titles in the taste profiles (section 5), changing every **1 minute** (configurable).
- Request backdrops at **1280 px wide** by default (sharp on 4K, light on the box). Size is a setting.
- Rolling cache: keep only the next few images, delete each after use, **hard cap 25 MB** (configurable).
- Hold at most **2 decoded images in RAM** (current + next for the crossfade) and release the old one right after the fade.
- **Optional source: Google Photos shared album** (the owner's daughter's album; the link is provided by the owner, not in this file).
  - Random order, shown at original size, **never upscaled**, max 4K (3840x2160). No minimum size. Use a blurred fill for photos smaller than the screen instead of stretching.
  - Shared-album pages are server-rendered with only about 25 photos initially; the rest lazy-load. Getting the full list needs unofficial endpoints that Google can change. Isolate this code behind an interface (`PhotoSource`) so the source can be swapped (for example to a Drive or OneDrive folder) without touching the UI. Do not rely on the official Google Photos Library API; it no longer covers this case.
  - Photo URLs on `lh3.googleusercontent.com` accept size suffixes such as `=w1920-h1080`.
- **Optional: follow-focus wallpaper** (background changes with the highlighted title). **Off by default** (costly).
- Respect Arc's existing wallpaper options (image, video, day/night, pitch black). The new sources are additions.

### 3.2 Recommendations row
- One row on the home screen: **"Recommended for you"**.
- Each card shows: poster, title, year, a one-line reason, a **person badge** (Dad / Mom / Dad + Mom / Kid), and where it is available to watch in Thailand.
- **Info cards only. No app launching.** Pressing OK opens a detail card.
- Auto-scroll through badge groups **only while idle**; it **stops as soon as the remote focuses the row**.
- 👍/👎 on each card updates that person's taste profile.
- Pipeline: read profiles, plus Watch Next titles (secondary signal), then ask Gemini for candidate titles, then **resolve each candidate through TMDB** (poster, rating, genres, watch providers for TH). Drop anything TMDB cannot resolve (the AI may hallucinate titles).
- Refresh **once a day** and on a manual "Refresh recommendations" button. Always render from cache.
- Send only titles and profile text to the AI. No other personal data.
- AI provider: **Gemini** (Flash-class model; the model name is a setting). The owner provides the key.

### 3.3 Settings shortcut tiles
- A row of configurable tiles the owner chooses from: Wi-Fi, Display, Storage, Apps, Bluetooth, HDMI/inputs, Google Play Store, general Android Settings.
- Use standard Android settings intents and test each on the box; some may be missing on Google TV.

### 3.4 Phone setup page (QR)
- In settings, show a **QR code and short local address**. The phone opens a simple page on the home Wi-Fi to paste: the Google Photos album link, the Gemini key and model name, and the TMDB key.
- The launcher runs a small local HTTP server **only while that settings screen is open**, then shuts it down. Make it clear to the user it is local-network only.
- Defaults come from a config file in the repo so the app works right after install.

### 3.5 Apps and icons
- Keep Arc's default icons and banners. Custom banners only where the owner sets them.

## 4. Arc features: keep all, set defaults

All stay in the app with settings toggles. Defaults for this box:

| Feature | Default |
|---|---|
| Backdrop blur | **Off** (Arc warns it lags on weak devices) |
| Video wallpaper | **Off** |
| Arc's own screensaver | **Off** (so the Google Photos screensaver stays in control) |
| Brightness scheduler (experimental, needs `WRITE_SETTINGS` via ADB) | **Off** |
| Data-usage widget | Owner's choice (leave on or off, do not remove) |
| Watch Next row, categories, favorites, clock, sounds | Keep Arc defaults |

Put a short warning next to blur and video wallpaper toggles about slow devices.

## 5. Taste profiles and the Gemini prompt

Profiles are editable in settings (free text plus thumbs history). Starting content:

- **Dad:** anime, especially isekai and food-themed (Reincarnated as a Slime, Campfire Cooking in Another World, The Eminence in Shadow, Daemons of the Shadow Realm) and shonen (One Piece, Demon Slayer, Jujutsu Kaisen); sci-fi and superheroes (Star Wars, Marvel, Spider-Man, Superman, Supergirl, Battlestar Galactica); action series (Reacher, A Shop for Killers); sitcoms (How I Met Your Mother, Friends, The Big Bang Theory, The IT Crowd). Likes series.
- **Mom:** Korean soaps and Chinese dramas.
- **Dad + Mom (shared):** Chinese fantasy and historical dramas (Fangs of Fortune, Pursuit of Jade, Keys to the Phoenix's Heart).
- **Kid (age 7):** cartoons and kids' shows (Doraemon, SpongeBob, Moana, Frozen). Likes YouTube, but YouTube history is not available to apps, so only suggest shows.
- **Dislikes (everyone):** horror and scary content. More can be added in settings.

Rules:
- **Kid picks must be filtered by age rating** (TV-Y / TV-Y7 / G, at most PG) using TMDB data, even if the AI suggests something else. Do not treat "animated" as "kid-safe". Dark anime (for example Demon Slayer, Jujutsu Kaisen) is **never** in the Kid row.
- Horror is filtered out for everyone using TMDB genres, as a safety net on top of the prompt.
- Ask Gemini for strict JSON (title, year, type, person, one-line reason), validate it, and retry once on bad output.
- Prefer taste notes ("isekai anime with comedy and food") over raw title lists when prompting, so results are similar titles rather than repeats.
- Do not recommend titles already in a person's liked list unless a new season exists.

## 6. Build phases (test on the TV after each)

1. **Base, shortcuts, performance.** Build Arc as-is, install on the box, measure startup and navigation. Add the settings shortcut tiles, set the defaults from section 4, and confirm the Home button approach works. Record baseline memory use.
2. **Movie-art wallpaper and QR setup page.** TMDB backdrop source with the rolling cache, the config-file defaults, and the phone setup page.
3. **Recommendations row.** Gemini plus TMDB pipeline, badges, idle auto-scroll, thumbs feedback, age filtering, daily refresh.
4. **Optional Google Photos album source**, then follow-focus wallpaper if the owner still wants it.

For each phase deliver: what changed, how to build and install (exact commands), what to test on the TV, and known risks.

## 7. Acceptance checks

- Remote navigation stays smooth on the home screen with wallpaper rotation running.
- Wallpaper cache never exceeds its cap; verify by listing the cache directory.
- No more than 2 decoded wallpaper images in memory (check with a profiler or logs).
- App works offline from cache and does not crash without keys or network.
- Kid row contains nothing above the allowed rating, and no horror anywhere.
- The Google Photos system screensaver still starts after idle.
- Every Arc feature is still reachable through settings.

## 8. Build and tooling notes

- Flutter version is pinned in `.fvmrc`; use FVM. The repo uses `drift` (see `drift_schemas/` and `build.yaml`); run code generation after schema changes and add a migration instead of editing existing schemas.
- Install over ADB to the box: `adb connect <box-ip>` then `adb install -r <apk>`. Use the owner's actual device IP.
- Keep the changelog updated and add short comments only where behavior is non-obvious.

## 9. Open questions to confirm with the owner

- Exact Mi Box model, Android/Google TV version, and RAM (check with ADB).
- Which Home button method works on this box.
- Whether the Google Photos shared-album listing still works at build time; if not, fall back to a Drive or OneDrive folder source.
- Whether TMDB watch-provider data for Thailand covers iQIYI, WeTV, and Crunchyroll well enough, and what to show when it does not.
