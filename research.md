# Sajda — Premium Viral Feature Research & Plan

> **Date:** October 19, 2026
> **Goal:** Make Sajda feel premium and grow organically (viral loops), with **zero extra server load** (small server at api.sajda.online), **open-source / copyright-clean** content, Flutter-compatible packages only.
> **App:** Sajda: Daily Athan & Qibla (`com.sajda.dataplus`) v1.0.3+4

---

## 1. Constraints

| Constraint | Meaning |
|---|---|
| Chota server | No new API endpoints. All features **on-device** (local calc, bundled data, SharedPreferences/Hive, local notifications) |
| Premium feel | Visual polish + depth — **no paid tier**, everything free |
| Global market | English-first UI (9 languages already translated), Muslim audience worldwide |
| Licensing | Only **MIT / BSD-3 / Apache / OFL** packages. Content only from **PD / CC0 / CC-BY (with attribution)** sources — no NC/ND |
| Google Play | Must pass Oct 2026 policy review (verified per-feature, see §6) |

---

## 2. Competitor Landscape (Play Store, Oct 2026)

| App | Scale / Price | Hooks | Missing vs Sajda |
|---|---|---|---|
| Muslim Pro | 100M+, ads + $9.99/mo | Quran, AI, community, **widget paywalled** | Aggressive ads, privacy history |
| Athan (IslamicFinder) | 10M+, $4.99/mo | Widgets, mosque, premium themes | Paywalled widgets |
| Just Pray | 4.9★, free | Garden of Deeds, Prayer Focus | Small ecosystem |
| Tarteel | AI Quran memorization | AI feedback | Server-heavy |
| Pillars | Privacy-first | Clean prayer tracker | No gamification |
| MuslimNow | 16 widgets, App Block | Widgets + focus | Region-limited |
| Thabat | "Garden of Consistency" | Visual streak garden | No qibla/radio |
| HalalYouNeed | Smart Fajr Rising | Shake-to-dismiss alarm | Alarm only |
| Awwab / Iqama | Quiz + Iqama times | Knowledge quiz, mosque IQ | Narrow features |
| Sadd Widgets | 14 home/lock widgets | Streak, wird, tasbih widgets | Widgets only |

**Sajda edge today:** prayer + qibla + full Quran + groups + streaks + tasbeeh + radio + 9 languages, free, no ads.

---

## 3. Gap Analysis — Sajda vs Best-in-Class

| Capability | Best competitor | Sajda today | Gap |
|---|---|---|---|
| Home/lock screen widgets | MuslimPro, Sadd (14!) | ❌ None | **Big** |
| Share/viral loops | Duolingo-style cards | ❌ None (basic ayah share only) | **Big** |
| Offline prayer calc | Pillars (on-device) | ⚠️ AlAdhan API + backend fallback | **Big** |
| Gamification depth | Thabat garden, badges | ⚠️ Streaks only | Medium |
| Yearly recap | MuslimPro Wrapped | ❌ | Medium |
| Knowledge/quiz | Awwab | ❌ | Medium |
| Seasonal Ramadan mode | MuslimPro | ❌ | Medium |
| Analytics heatmap | None dominant | ❌ | **Opportunity** |

---

## 4. Feature Shortlist (11 features — approved list)

> Order = implementation order (1 by 1). Risk rating from Google Play Oct 2026 policy review (§6).

### Tier 1 — Viral & Core (Priority: HIGH)

#### F1. Shareable Streak/Achievement Cards
- **What:** Beautiful PNG cards (streak milestones, 5/5 prayers complete, badge unlock) rendered locally → share to WhatsApp/Instagram stories via ShareSheet + prefilled caption + `sajda://` deep link.
- **Value:** Every share = free ad. Duolingo-style loop; deep-link attribution tracks referral installs.
- **Server load:** 0 (local PNG via `screenshot` package)
- **Packages:** `screenshot` (**MIT**, verified pub.dev), `share_plus` (already in pubspec, BSD-3)
- **Policy:** ✅ SAFE — refer-a-friend rewards have no Play rule; NEVER tie reward to rating/review (banned); reward = in-app benefit only.
- **Effort:** M (S) — card widget + capture + share flow.

#### F2. Home Screen Widgets (Next Prayer + Streak)
- **What:** 2 Android widgets: (a) next-prayer countdown ring, (b) streak + today's prayers mini-grid. Updated via `HomeWidget.saveWidgetData` + `updateWidget`.
- **Value:** Brand on home screen 20-30×/day = retention; competitors paywall this, Sajda gives free = differentiator.
- **Server load:** 0
- **Packages:** `home_widget` (**BSD-3-Clause**, verified pub.dev) + native widget layouts (Kotlin/RemoteViews)
- **Policy:** ✅ SAFE — user adds widget themselves (consent); no auto-shortcuts.
- **Effort:** M — 2 XML layouts + Kotlin provider + Dart bridge.

#### F3. On-Device Prayer Calculation + Offline Cache
- **What:** Calculate prayer times locally with `adhan` (Karachi method, Hanafi madhab to match current backend); cache 30 days in local storage. API calls become optional (offline always works).
- **Value:** Offline 100% functional; **~90% fewer AlAdhan/backend calls** = chota server ka load kam.
- **Server load:** 0 (actually reduces)
- **Packages:** `adhan` (**MIT**, verified pub.dev)
- **Policy:** ✅ SAFE — no permissions needed (coordinates already obtained for qibla).
- **Effort:** M — service + cache + fallback chain (local → API → backend).

### Tier 2 — Premium Feel & Retention (Priority: MEDIUM)

#### F4. Badges + Prayer Heatmap Analytics
- **What:** 15-20 badges (first streak, 7/30/100 days, 5/5 x7, early bird, tasbeeh milestones) + GitHub-style contribution heatmap (year grid, per-prayer breakdown, punctuality %).
- **Value:** Gamified progress beyond streaks; heatmap is sticky and screenshot-worthy.
- **Server load:** 0 (local stats)
- **Packages:** none new (custom painter for heatmap)
- **Policy:** ✅ SAFE — zero permissions.
- **Effort:** M — badge defs + stats store + 2 screens.

#### F5. Islamic Quiz (Bundled Question Bank)
- **What:** 300+ MCQs bundled as JSON (Quran facts, Pillars, Seerah, prayer rules) from public-domain sources; daily challenge, streak, score share card.
- **Value:** Knowledge audience tap; score sharing = invite loop.
- **Server load:** 0 (bundled asset)
- **Packages:** none new
- **Policy:** ✅ SAFE — content must be PD/licensed (see §5).
- **Effort:** M — JSON bank + quiz UI + daily scheduler.

#### F6. Sajda Wrapped (Yearly Recap)
- **What:** "Your Year in Worship" card deck: prayers completed, longest streak, top surah, minutes of radio/tasbeeh, badges earned → shareable story-format images.
- **Value:** Spotify-Wrapped-style organic viral spike (Dec/Ramadan).
- **Server load:** 0 (local stats)
- **Packages:** `screenshot` (reuse from F1)
- **Policy:** ✅ SAFE.
- **Effort:** S-M — stats aggregation + story cards (reuse F1 renderer).

#### F7. Prayer Garden (Jannah Garden)
- **What:** Visual garden that grows with daily streaks — plants/trees tied to deeds (prayer streak = trees, tasbeeh = flowers, badges = ornaments). Animated, local, procedural.
- **Value:** Emotional attachment + "wow" screenshots. No PK-market competitor does this at Sajda's scope.
- **Server load:** 0
- **Packages:** none new (custom painter / sprite assets, OFL fonts)
- **Policy:** ✅ SAFE — zero permissions.
- **Effort:** L — garden state model + rendering + growth rules.

### Tier 3 — Growth Extras (Priority: LOW)

#### F8. Card Studio (Ayah / 99 Names / Dua Posters)
- **What:** Premium poster maker — pick ayah/name/dua, choose background theme + font, export PNG with Sajda watermark + store link.
- **Value:** Every share = free ad; global audience reach.
- **Server load:** 0
- **Packages:** `screenshot` (reuse)
- **Policy:** ✅ SAFE — only licensed content (Tanzil CC BY attribution already in app).
- **Effort:** M.

#### F9. Group Challenges + Leaderboard
- **What:** Weekly group challenge (e.g. all 5 prayers × 7 days) + leaderboard of group members by streak/completion. Invite = ShareSheet + `sajda://join/CODE` (no contacts permission).
- **Value:** Social commitment = retention + natural invite loop (K-factor).
- **Server load:** minimal (existing streak v2 API, no new endpoints)
- **Packages:** none new
- **Policy:** ✅ SAFE — no READ_CONTACTS, leaderboard shows **names only** (no free-text chat → no UGC moderation burden).
- **Effort:** M.

#### F10. Ramadan Mode
- **What:** Seasonal dashboard: suhoor/iftar countdown (from local prayer times), Ramadan calendar, 2x streak event, daily iftar reminder notification.
- **Value:** Seasonal viral spike + annual ASO boost; dates from `hijri` package (already in pubspec).
- **Server load:** 0
- **Packages:** none new
- **Policy:** ✅ SAFE — same SCHEDULE_EXACT_ALARM/local notifications already in use.
- **Effort:** S-M.

#### F11. Daily Zikr/Dua Reminder Polish
- **What:** Opt-in daily notification ("Ayah of the Day" / "Dua of the Day") bundled from PD sources, with category opt-out in Settings.
- **Value:** Re-engagement channel (retention), zero cost.
- **Server load:** 0 (local scheduled notifications)
- **Packages:** `flutter_local_notifications` (already in pubspec)
- **Policy:** ✅ SAFE — notifications must be integral feature + user opt-out (per Play notification rules).
- **Effort:** S.

---

## 5. Licensing Cheat-Sheet

### ✅ Safe sources (used for content)
| Content | Source | License |
|---|---|---|
| Quran text (Arabic) | Tanzil.net | CC BY 3.0 — attribution ✅ already in app (legal screen) |
| English translation | Pickthall | Public Domain |
| Urdu translation | Jalandhry (Tanzil) | Free distribution with attribution |
| Adhan audio | `assets/audio/adhan.ogg` | CC0 (Aishatu98, Wikimedia) ✅ already used |
| Dua / 99 Names texts | Classical, public domain | PD |
| Quiz questions | Written in-house from Quran/PD translations | Own work |
| Fonts | Amiri, Noto, Scheherazade | OFL |

### ❌ Avoid
| Source | Why |
|---|---|
| ClearQuran translation | CC BY-**ND** (no derivatives) |
| data-quran repo | CC BY-**NC-ND** (non-commercial) |
| Sahih International / modern hadith translations | Copyrighted — license review required, prefer in-house text from PD classical works |
| Tarteel/QUL content packs | Mixed licenses — review per item |

### ✅ Package licenses (verified on pub.dev, Oct 2026)
| Package | License |
|---|---|
| `adhan` | MIT |
| `home_widget` | BSD-3-Clause |
| `screenshot` | MIT |
| `share_plus`, `share_plus_platform_interface` | BSD-3-Clause |
| `flutter_local_notifications`, `hijri`, `uuid`, `provider` | MIT/BSD (existing deps) |

---

## 6. Google Play Policy Compliance (Oct 2026 policies)

### ✅ Approved features (all 11 — verified SAFE)
All approved features need **zero new permissions** — zero policy surface.

| Feature | Verdict |
|---|---|
| F1 share cards + referral | SAFE — Play has **no rule against refer-a-friend rewards**; red lines: never reward ratings/reviews (banned), reward = in-app benefit only, share must be user-initiated |
| F2 widgets | SAFE — user-initiated; policy only bans *auto-added* shortcuts without consent |
| F3 local calc | SAFE — no permissions |
| F4 badges/heatmap | SAFE — no permissions |
| F5 quiz | SAFE — notifications = integral feature; PD content only (IP policy) |
| F6 Wrapped | SAFE — no permissions |
| F7 garden | SAFE — no permissions |
| F8 card studio | SAFE — licensed content only |
| F9 group challenges | SAFE — invite via ShareSheet + code (NO READ_CONTACTS); leaderboard = names only, no free-text chat (avoids UGC moderation) |
| F10 Ramadan mode | SAFE — uses existing SCHEDULE_EXACT_ALARM + local notifications |
| F11 daily reminders | SAFE — opt-out required, integral feature |

### ❌ Dropped features (policy risk — do not implement)
| Feature | Reason |
|---|---|
| App Block / Prayer Focus | AccessibilityService policy (enforced Jan 28, 2026): app = "monitoring tool" → cannot claim `isAccessibilityTool`; needs Play Console a11y declaration + prominent disclosure + consent. Viable via Opal/one sec precedent but **excluded by decision** |
| Force-Wake Fajr Alarm | `USE_EXACT_ALARM` = restricted (alarm-core only); `USE_FULL_SCREEN_INTENT` declaration may be rejected. Existing SCHEDULE_EXACT_ALARM notifications cover the need |
| Contacts-based invites | READ_CONTACTS banned for invites from Jan 27, 2027 — ShareSheet alternative used instead |
| Location-button migration | Location policy effective Jan 27, 2027 — revisit when targeting Android 17 |
| Zakat calculator + Sunnah fasting tracker | Financial/health = sensitive Data Safety declarations; excluded by decision |

### 📋 App-level compliance checklist (independent of features)
- [ ] **Target API 36** — required since Aug 31, 2026 (verify `flutter.targetSdkVersion`)
- [ ] **Developer verification** — required since Sep 30, 2026 (check Play Console home)
- [ ] **Data deletion** — required for apps with accounts (Firebase Auth) since 2026
- [ ] **Content rating** — unrated apps not allowed (Jul 2026 clarification)
- [ ] **Data Safety form** — keep current (location, account info) accurate

---

## 7. 90-Day Roadmap

| Phase | Weeks | Features |
|---|---|---|
| **1 — Viral core** | 1–3 | F3 local calc + offline, F2 widgets, F1 share cards |
| **2 — Retention** | 4–7 | F4 badges + heatmap, F7 Prayer Garden, F6 Wrapped |
| **3 — Depth** | 8–10 | F5 Quiz, F10 Ramadan Mode, F8 Card Studio |
| **4 — Social + polish** | 11–13 | F9 Group challenges, F11 reminders, compliance checklist |

---

## 8. Avoid List (server-heavy / out of scope)

Mosque finder · Halal location finder · Live TV/radio streams (beyond existing) · AI chat/tafsir (server) · Social feed · Cloud sync of everything · Any feature needing new api.sajda.online endpoints.

---

## 9. Execution Log

| # | Feature | Status |
|---|---|---|
| — | research.md | ✅ Done (this file) |
| F3 | On-device prayer calc + offline cache | ✅ Done |
| F2 | Home screen widgets | ✅ Done |
| F1 | Shareable streak cards | ✅ Done |
| F4 | Badges + heatmap | ✅ Done |
| F5 | Islamic Quiz | ✅ Done |
| F6 | Sajda Wrapped | ✅ Done |
| F7 | Prayer Garden | ✅ Done |
| F8 | Card Studio | ✅ Done |
| F9 | Group challenges | ✅ Done |
| F10 | Ramadan Mode | ✅ Done |
| F11 | Daily reminder polish | ✅ Done |

---

## 10. Session Log (resume point)

### Session 1 — Oct 19, 2026 (DONE)

**Research (complete):**
- Competitor analysis, 11-feature shortlist, licensing verification (pub.dev: `adhan` MIT, `home_widget` BSD-3, `screenshot` MIT), Google Play Oct 2026 policy review → 11 approved / 5 dropped (App Block, Fajr force-wake, Contacts invite, Location migration, Zakat/fasting — see §6)

**F3 — On-device prayer calc (complete, verified):**
- Added `adhan: ^2.0.0+1` to pubspec
- Created `lib/services/local_prayer_times_service.dart` — local calculation, 8 method mappings (Karachi/ISNA/MWL/UmmAlQura/Egyptian/Gulf/Moonsighting/Diyanet), Hanafi/Asr school, location-timezone wall-clock via `tz` package (device-TZ independent)
- Wired **local-first** into `ApiClient.getPrayerTimesFor` and `getNextPrayerByCoords` (`lib/services/api_client.dart`) — network paths kept only as safety-net fallbacks; city-only mode (no coords) still uses API
- Bonus bugfix: `getNextPrayerByCoords` was sending YYYY-MM-DD to AlAdhan `/timings/{date}` (year misread) → now DD-MM-YYYY
- Extracted shared `_buildNextPrayer()` helper (paren-stripping + int.tryParse hardening)
- Tests: `test/local_prayer_times_test.dart` (7 tests: HH:mm format, Karachi ranges + ordering, Hanafi > Shafi Asr, Tokyo +4h offset proof, zero-coords null, unknown TZ fallback, all 8 method ids)
- **Verify:** `flutter analyze` → 0 errors (2 pre-existing infos), `flutter test` → **72/72 pass**

### Session 2 — Oct 19, 2026 (DONE)

**F2 — Home screen widgets (complete, verified):**
- Added `home_widget: ^0.10.0` (BSD-3) to pubspec
- Created `lib/services/widget_service.dart` — pure, unit-tested mappers `prayerKeyValues()`/`streakKeyValues()` + guarded fire-and-forget `savePrayerTimes()`/`saveStreak()` writing into home_widget's `HomeWidgetPreferences`, then `updateWidget(name: …)` for the two providers
- Save hooks: prayer times (`ApiClient.getPrayerTimesFor` after cache store), streak (`StreakState`: refreshSolo / togglePrayer optimistic + server response / startSolo / reset)
- Android resources: `res/drawable/sajda_widget_bg.xml`, `res/layout/sajda_prayer_widget.xml` (next-prayer header + 5-column row; ids `widget_root`, `widget_next`, `widget_tomorrow`, `widget_fajr`…`widget_isha`), `res/layout/sajda_streak_widget.xml` (ids `widget_streak_root/_days/_dots/_today`), `res/xml/sajda_prayer_widget_info.xml` + `sajda_streak_widget_info.xml` (30-min updatePeriodMillis, previewLayout, target cells 4×2 / 2×2)
- Created `res/values/strings.xml` (was missing — widget descriptions live here)
- Kotlin: `SajdaPrayerWidgetProvider.kt` (reads `HomeWidgetPreferences`, computes next prayer vs `LocalTime.now()`, tomorrow-wrap after Isha, 12-hour display, tap→launcher PendingIntent, recompute on TIME_SET/TIMEZONE_CHANGED) + `SajdaStreakWidgetProvider.kt` (streak count + ●/○ 5-dot progress; day-rollover guard via `widget_date` resets today to 0/5) — `java.time` safe (core-library desugaring already enabled in build.gradle.kts)
- Manifest: both receivers registered (APPWIDGET_UPDATE + TIME_SET + TIMEZONE_CHANGED, `exported="false"`, meta-data → info XMLs)
- Fix during build: `AppWidgetManager.getAppWidgetIds()` needs `ComponentName`, not `Intent`
- Tests: `test/widget_service_test.dart` (4 tests: key mapping incl. Sunrise exclusion, absent-prayer tolerance, null solo zeros, streak values)
- **Verify:** `flutter analyze` → 0 errors (2 pre-existing infos), `flutter test` → **85/85 pass**, `flutter build apk --debug` → √ builds
- ⚠️ Manual QA still open: run on a device, long-press home screen → widget picker should list two Sajda widgets (this environment has no emulator)

### Session 3 — plan (kept for reference; F1 completed earlier)
**Next feature: F1 — Shareable streak cards (zero server load)**
1. Verify `screenshot: ^3.0.0` (MIT) is in pubspec → `flutter pub add screenshot`; `share_plus` already present
2. Create `lib/services/share_card_service.dart` — pure builder (unit-tested): renders a `RepaintBoundary`-friendly card widget (streak count, best, 5-dot today row, month label, app name `sajda.app` link/wordmark, NO leaderboard/chat, user-initiated share only) → `ScreenshotController.capture()` → `Share.shareXFiles()` (PNG in temp dir)
3. Entry point: share button on Streak Home / Solo Dashboard (icon button, existing screens)
4. Attribution: if any art/copy beyond own CC0 → add credit line per §5 of this file
5. Tests: builder output keys/structure (no PII, correct numbers), analyze + full test run + debug build

**Then:** F4 badges/heatmap → F5 quiz → F6 Wrapped → F7 Prayer Garden → F8 Card Studio → F9 group challenges → F10 Ramadan Mode → F11 reminder polish (per §9 order).

### Session 4 — Oct 19, 2026 (DONE — F4–F11)

**Shared foundation:**
- `lib/services/sajda_stats_service.dart` — local SharedPreferences stats (`sajda_stats_v1`): per-day counts + 5-prayer flags, per-prayer totals, tasbeeh sets, quiz correct/days; `syncToday` from solo state (hooked in `StreakState`), `mergeHistory` backfill, `snapshot()` for badges/cards.
- `lib/main.dart` — provider registration; `AppState` prefs for Ramadan + daily reminder (`sajda_ramadan_reminders`, `sajda_daily_reminder`, `sajda_daily_reminder_category`).

**F4 — Badges + heatmap (done):**
- `lib/data/badges.dart` (18 badges: streak, prayer totals, Fajr/Isha, active days, tasbeeh, quiz) + `lib/screens/achievements_screen.dart` (hero stats, 17-week GitHub-style heatmap, per-prayer breakdown row, badge grid/detail/share PNG, 3-month history backfill).
- Entry points: trophy in Solo Dashboard app bar, “Achievements” in More.

**F5 — Islamic quiz (done):**
- `lib/services/quiz_service.dart` — 341 offline questions generated from the bundled `quran` package (surah length/order/number), deterministic daily 10 via stable hash, 4 unique options, progress + streak in `sajda_quiz_progress_v1`, stats hook; `lib/screens/quiz_screen.dart` daily UI/result/share.

**F6 — Sajda Wrapped (done):**
- `lib/screens/wrapped_screen.dart` — 5 shareable story cards (prayers, streak, tasbeeh, badges, year journey). Limitation: top surah / radio minutes are not tracked locally, so they are not shown.

**F7 — Prayer Garden (done):**
- `lib/screens/prayer_garden_screen.dart` — procedural `CustomPainter` garden (trees = streak/completions, flowers = tasbeeh, fireflies), animated, stats summary + share card.

**F8 — Card Studio (done):**
- `lib/data/card_content.dart` (12 curated ayahs, 10 duas, 5 themes) + `lib/screens/card_studio_screen.dart` — Ayah / 99 Names / Du'a posters, theme picker, PNG export with Sajda watermark/store link.

**F9 — Group weekly challenge (done):**
- `lib/utils/group_challenge.dart` — pure Monday→Sunday builder from existing month history + member ranking; `lib/screens/group_challenge_screen.dart` — week hero, per-day grid, leaderboard, how-it-works, share text; entry card in `group_dashboard_screen.dart`. No new API endpoints, names only.

**F10 — Ramadan Mode (done):**
- `lib/services/ramadan_service.dart` — Hijri detection (month 9), local Maghrib calculation, 30-day iftar reminders (IDs 9600–9630, same-day guard), cancel; `lib/screens/ramadan_screen.dart` — Suhoor/Iftar countdown, 30-day calendar, reminder toggle, pre-Ramadan countdown; home banner during Ramadan. Limitation: 2x streak is server-side and was not implemented (no new endpoints).

**F11 — Daily Zikr/Du'a (done):**
- `lib/data/daily_reminders.dart` (7 zikr + 5 du'a, PD sources, stable rotation) + `lib/services/daily_reminder_service.dart` (next 7 days at 08:00, channel `daily_zikr`, IDs 9500–9507) + `lib/screens/daily_zikr_screen.dart` (today, upcoming, category filter, share).
- Settings: toggle + content picker (all / zikr / du'a) with permission request and reschedule; `NotificationRouter` routes `daily_reminder` and `ramadan_iftar` payloads.

**Verification:**
- `flutter analyze` → **0 errors, 2 pre-existing infos** (`device_preview` dependency info, `streak_v2_api.dart` null-aware info).
- `flutter test` → **119/119 pass** (new: `badges_test.dart`, `group_challenge_test.dart`, `daily_reminders_test.dart`, `quiz_service_test.dart`, `sajda_stats_service_test.dart`).
- `flutter build apk --debug` → √ `build/app/outputs/flutter-apk/app-debug.apk`.
- ⚠️ Manual device QA still open: notification permission + 8 AM/iftar scheduling, share sheet on Android, Urdu/RTL layouts, tappable notification deep links.
- ⚠️ Note: never write Urdu via PowerShell `Add-Content`/`Set-Content` — it corrupts UTF-8; use the editor tools (fixed once in `group_dashboard_screen.dart`).

### Session 5 — Oct 19, 2026 (DONE — prayer-time timezone bug fix)

**Report:** Rahim Yar Khan phone showed Isha 3:59 PM / next Fajr 2:03 AM on Oct 19, 2026 (~3h early); Raiwind phone was correct.

**Root cause:** `timezone_finder` 0.2.0 takes `findLocation(longitude, latitude)`, but `app_state.dart` called `findLocation(lat, lng)`. Rahim Yar Khan (28.3902, 70.3216) was read as (lat 70.32, lng 28.39) → northern Norway → **Europe/Oslo** (UTC+2 DST) stored as the location timezone instead of Asia/Karachi (UTC+5) → every wall-clock time 3h early. Raiwind/Lahore mirrored point was open ocean → `null` → device-timezone fallback (Asia/Karachi) → correct by luck.

**Evidence (reproduced in tests):** RYK + Asia/Karachi + Karachi method = Fajr 05:03 / Isha 19:04 (matches public references); RYK + Europe/Oslo + MWL = Fajr **02:03** / Isha **15:59** (exact screenshot values); shift exactly 3h.

**Fix:**
- `lib/services/timezone_lookup.dart` (new) — `ianaTimezoneForCoordinates(lat, lng)` wrapper with the correct `(lng, lat)` order, `latest_all` init, null for ocean/UTC; all coord→zone lookups go through it.
- `lib/state/app_state.dart` — `_resolveTimezone` uses the helper; `load()` now runs `_healStoredLocation()`: re-resolves the stored location's timezone from its coordinates (rewrites e.g. Europe/Oslo → Asia/Karachi on existing installs) and re-applies the country auto prayer method for non-manual users; Pakistan auto default switched MWL → **Karachi method (1) + Hanafi** to match the F3 spec and reference times (manual picks untouched).
- `lib/services/local_prayer_times_service.dart` — unsupported method ids now return `null` (network fallback) instead of silently using MWL.

**Regression tests:** `test/timezone_lookup_test.dart` (5), `test/prayer_times_regression_test.dart` (7: exact RYK/Raiwind values, bug reproduction, civil-date and ordering invariants), `test/local_prayer_times_test.dart` (+1 unsupported method id).

**Sajda Wrapped back button (reported same day):** bottom "Back" (پیچھے) button was a silent no-op on the first story card (`previousPage` clamps at page 0). Fix in `lib/screens/wrapped_screen.dart`: page > 0 → previous card, page 0 → `Navigator.maybePop()` (leaves the screen, never a dead tap). AppBar back verified working (both entry points: All Features sheet and Achievements action). New widget tests: `test/wrapped_screen_test.dart` (4).

**Verification:** `flutter analyze` → 0 errors, same 2 pre-existing infos; `flutter test` → **136/136 pass**; `flutter build apk --debug` → deferred by user (the on-disk `build/app/outputs/flutter-apk/app-debug.apk` predates these Session 5 fixes).

**Limitations:** existing installs are healed on next app launch (`_healStoredLocation`), not at update time; method default for India/Bangladesh etc. still MWL; on-device verification on the two reported phones still pending.

### Session 6 — Oct 19, 2026 (DONE — streak/group audit fixes)

**Audit:** full read of every streak/group screen, widget, util, state, API and the backend controller/logic; two bugs reproduced with a throwaway widget test (deleted after; no app code changed during the audit).

**Fixed:**
- **P1 GroupPrayerCircle layout** (`group_prayer_circle.dart`): the outer `Stack` shrink-wrapped to the 96px hub, so with `alignment: center` from a 220px slot the ring center landed 34px right / 27px up of the card center and side avatars were clipped (`Clip.hardEdge`). Now a `Center`+`SizedBox(size, size)` keeps the stack square and `_positionedAvatar` orbits `center` (`size/2`), radius `size/2 - 28`.
- **P2 weekly challenge month boundary** (`group_challenge.dart` + `group_challenge_screen.dart`): a Monday start in the previous month (e.g. Mon Sep 28 for the week of Oct 4) meant Sep 28–30 were missing from the fetched month and shown as **missed**. Added pure `mergeMonthHistories` (first occurrence wins) and the screen now fetches the previous month too when the week starts in it. Also switched "today" to the **group** `dateKey` from the dashboard payload (device clock no longer drives the grid).
- **P2 activity feed raw strings** (`streak_components.dart`): `group_shield_used` and `group_archived` fell through to `default` and rendered the raw snake_case type. Both now have localized sentences + icons; the default fallback is generic localized "Group activity".
- **P3 ghost member double badge**: excluded (3-day ghost) members also have `required: false`, so they showed both "from tomorrow" and "inactive". Badge now requires `!excludedInactive`; the same guard added to the dashboard "counts from today" banner.
- **Misc production polish:** nudge `NUDGE_DUPLICATE` copy no longer mentions "another prayer" (client can't send prayers) — "Already nudged today — try again tomorrow"; notifications sheet no longer renders a trailing " · " when `notifGroupName` is empty; `GroupPreviewScreen` gained optional `initialPreview` and `JoinWithCodeScreen` passes the already-fetched preview (no double fetch; deep-link call site unchanged); backend `createGroup` now returns the full GroupDetail payload (`status`, `memberCount`, `myRole: 'owner'`, `isOwner`, streaks, `dateKey: activePrayerDayKey(tz)`) instead of the sparse 5-field response.

**Regression tests:** `test/group_prayer_circle_test.dart` (3: square centered stack, all 5 avatars exactly on the ring and inside the stack bounds, `+N` chip on the same ring), `test/group_challenge_test.dart` (+3: merge summaries/dedupe, month-spanning week completes 4 days, without-merge control still 1), `test/streak_components_test.dart` (6: shield/archived/unknown/generic + groupName suffix, ghost vs new-joiner badges).

**Verification:** `flutter analyze` → 0 errors, same 2 pre-existing infos; `flutter test` → **148/148 pass**; backend `node --test` → **54/54 pass**; controller syntax checked. Backend change needs a redeploy to take effect on devices. Debug APK rebuild still deferred by user.

### Session 7 — Oct 20, 2026 (DONE — group-streak E2E tester + 2 backend bugs found & fixed)

**New tool:** `backend/test/group_streak_e2e.py` — dependency-light end-to-end tester (stdlib `urllib` + minted HS256 JWTs + `pymongo` for DB seeding; `zoneinfo` for tz math). Creates 10 tagged groups (`TEST-<run>-01..10`) with random members + dedicated extras (ghost trio, joiner, stranger, owners), then exercises every group-streak rule through the real API: create/join/discover/approve/decline, backdating, day-completion gating, streak walk, 3-day ghost exclusion, weekly shield + per-week limit, new-joiner "from tomorrow" rule, month history (two months), timezone day boundaries (UTC + New York), rename/rotate/leave/rejoin/nudge/notifications/archive. Flags: `--base-url --env-file --jwt-secret --mongo-uri --db-name --seed --no-db --cleanup --cleanup-only --report`; prints PASS/FAIL/SKIP per check, exit 1 on any FAIL. Default seed 42 (deterministic rosters). Grace-window-aware: the un-tick/revert pair is skipped when the group tz is inside the 04:00 grace (the completed day is locked by design).

**Bugs found by the tester (both in `backend/backend/controllers/streakV2Controller.js`):**

- **Dashboard eligibility dead (`getGroupDashboard`)**: the members query selected `userId displayName role effectiveFromDate` but `isMemberEligibleOn` also checks `member.status === 'active'` — with `status` not selected it was `undefined` for every member ⇒ `eligible: false` and `today.required: 0` on **every** dashboard read (members always shown greyed/ineligible). Fixed by adding `status` to the select. Verified live: `required` went 0 → 5, `eligible` false → true.
- **500 on the 5th tick of an already-complete day (`maybeCompleteGroupDay`)**: the conditional `findOneAndUpdate({... isGroupDayComplete: false}, …, {upsert: true})` retries as an INSERT when the day is already complete; the unique `groupId+dateKey` index then throws E11000, bubbling up as an HTTP 500 on an idempotent tap (re-tick after un-tick, tick by a member finishing after the day completed). Fixed with `.catch(e => e?.code === 11000 ? null : throw)` → returns false (no-op). Reproduced in isolation before/after.

**Tester hardening after run 1 (19 fails → root-caused):** deep backdating (10 days) made unticked members 3-day "ghosts", so group days completed early with partial membership — default backdate is now **1 day** (immune to ghost exclusion; `effectiveFromDate` ≥ 3 days back = ghost-subject), with 10 days kept only where the scenario needs it (ghost group, history month anchor). Joiner scenario backdates the owner 1 day (owner was otherwise effective "tomorrow" ⇒ never required). Streak/shield-limit scenarios now clear their active-day rows + streak anchor first so earlier fan-outs can't pre-complete their premise. Grace-window un-tick asserts auto-skip.

**Result (run 2, live backend + Atlas `sajda_local_test`):** `347 passed, 0 failed, 2 skipped`, exit 0. Report: `group_streak_report_run2.json`. Backend unit tests still **54/54**. Test data cleaned up afterwards (`--cleanup-only`, both runs). Backend fixes need a redeploy (Railway) to reach production; APK rebuild still deferred by user.

### Session 8 - Oct 20, 2026 (DONE - backend fixes deployed to VPS)

**Commit:** `d4d4e11` `fix: streak v2 grace cutoff, dashboard eligibility, completion race, createGroup response` - only `backend/backend/controllers/streakV2Controller.js` (28 insertions / 7 deletions). Includes both Session 7 tester-found fixes (dashboard `status` select, E11000-safe `maybeCompleteGroupDay`) plus the earlier uncommitted Session 6 changes (client `fajrMinutes` grace cutoff, full `createGroup` GroupDetail payload). All other uncommitted work left untouched.

**Deploy (per DEPLOYMENT.md Section 0):** pushed `main` `4b910f6..d4d4e11`; SSH to OVH VPS (password via `SSH_ASKPASS` from `vps.md`, never echoed), `cd /home/ubuntu/S-Backup/sajda && git pull` (fast-forward) -> `cd backend && npm install --omit=dev` -> `pm2 restart sajda-api --update-env`. New PID 710458, status online.

**Verified:** `GET https://api.sajda.online/api/health` -> 200 `{"status":"ok"}`; VPS HEAD = `d4d4e11`; deployed file line 787 has `role effectiveFromDate status`, line 330 has `e?.code === 11000`, 6 `fajrMinutes` hits. Server log shows MongoDB connected + port 5001; only pre-existing Mongoose deprecation/duplicate-index warnings (non-fatal).

**Legal audit (same day, pending action):** in-app `legal_screen.dart` is link-only (policy.sajda.online + /delete-account/), no change needed. Live policy source = gitignored `temp_policy/index.html` (Last Updated Sep 20, 2026, served from VPS nginx); repo-root `privacy_policy.html` is a stale Sep 14 copy. Live policy does NOT yet disclose Group Challenges v2 data (group/member display names, shared prayer data, leaderboard, join requests/invites), nudges (server push to other members), or FCM + server-stored `PushToken` device tokens. Deletion controller already removes GroupMember/JoinRequest/PushToken/GroupDailyProgress and heir-transfers or archives owned groups. Policy update drafted but NOT yet approved/deployed.

**Still pending:** privacy policy update approval + deploy; debug APK rebuild; real-device verification.

