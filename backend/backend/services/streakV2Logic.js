// Pure, DB-free business rules for the v2 streak system (Friends & Family
// groups + Solo). Unit-tested with `node --test`. Reuses the shared
// calendar-day logic from streakLogic.js — a streak day is a CALENDAR DAY
// key in a defined timezone, never a rolling 24-hour window.
import crypto from 'crypto';
import {
  PRAYERS,
  todayKeyInTz,
  nextDateKey,
  previousDateKey,
} from './streakLogic.js';

// Unambiguous alphabet (no 0/O/1/I) so codes can be read from share text
// and typed reliably.
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export const GROUP_MEMBER_LIMIT_DEFAULT = 50; // configurable, one source of truth
export const GROUP_NAME_MAX = 60;
export const ACTIVITY_PAGE_SIZE = 20;
export const DISCOVER_PAGE_SIZE = 20;

export const randomCode = (length = 6) => {
  const bytes = crypto.randomBytes(length);
  let out = '';
  for (let i = 0; i < length; i++) {
    out += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
  }
  return out;
};

export const newGroupId = () => `grp_${randomCode(10).toLowerCase()}`;

/// The first dateKey a NEW member counts towards group completion.
/// Rule: a member joining today becomes a required member from the NEXT
/// streak day — they can never retroactively break an existing streak.
export const effectiveFromForJoin = (now, groupTimezone) =>
  nextDateKey(todayKeyInTz(groupTimezone, now));

/// Whether a member counts towards group completion on [dateKey].
export const isMemberEligibleOn = (member, dateKey) => {
  if (!member || member.status !== 'active') return false;
  return String(member.effectiveFromDate) <= String(dateKey);
};

/// Group day completion check over today's member rows.
/// `rows`: [{ userId, isDayComplete }] — one per ACTIVE ELIGIBLE member
/// (missing row = member has not started/prayed = incomplete).
/// A group day completes ONLY when EVERY eligible active member is 5/5.
export const isGroupDaySatisfied = (eligibleMembers, rows) => {
  if (!eligibleMembers || eligibleMembers.length === 0) return false;
  const completeByUser = new Set(
    (rows || []).filter((r) => r.isDayComplete).map((r) => String(r.userId)),
  );
  return eligibleMembers.every((m) => completeByUser.has(String(m.userId)));
};

/// A day (solo or a member's group row) counts as complete ONLY when ALL
/// five prayers are ticked — derived from completedCount, NEVER from the
/// request's completed flag. This is the single source of truth for the
/// derived-write used by the controller and the repair script.
export const dayCompleteFromCount = (completedCount, total = PRAYERS.length) =>
  (Number(completedCount) || 0) >= total;

/// DAILY STREAK RULES (counter-based contract, unit-tested):
///  - Same day:          keep the current streak intact (idempotent).
///  - Consecutive day:   lastActive was YESTERDAY -> currentStreak + 1.
///  - Missed >= 2 days:  lastActive older than yesterday -> reset to 1.
/// `lastActiveDateKey === null` means a brand-new streak -> 1.
export const applyDailyStreakRules = (currentStreak, lastActiveDateKey, todayKey) => {
  if (!lastActiveDateKey) return 1; // first ever day
  if (lastActiveDateKey === todayKey) return Math.max(1, currentStreak); // same day: intact
  if (nextDateKey(lastActiveDateKey) === todayKey) return currentStreak + 1; // consecutive: +1
  return 1; // missed >= 2 days: reset
};

/// Current streak walk over day-complete records.
/// `completeDays`: Set of dateKeys that were completed.
/// Walks back from today (if complete) else yesterday — the streak stays
/// alive through yesterday while today is still in progress — and stops at
/// the first missing/incomplete past day. Returns the run length and the
/// run's first day.
export const currentRunFromDays = (completeDays, todayKey) => {
  const set = completeDays instanceof Set ? completeDays : new Set(completeDays || []);
  let cursor = todayKey;
  if (!set.has(cursor)) cursor = previousDateKey(todayKey); // today still in progress
  let run = 0;
  while (set.has(cursor)) {
    run += 1;
    cursor = previousDateKey(cursor);
  }
  return { run, startDate: run > 0 ? nextDateKey(cursor) : null };
};

/// Longest run of consecutive completed day keys (whole history).
export const longestRunFromDays = (completeDays) => {
  const keys = [...(completeDays instanceof Set ? completeDays : new Set(completeDays || []))]
    .filter(Boolean)
    .sort();
  let best = 0;
  let run = 0;
  let prev = null;
  for (const k of keys) {
    run = prev !== null && nextDateKey(prev) === k ? run + 1 : 1;
    if (run > best) best = run;
    prev = k;
  }
  return best;
};

/// History calendar for a month: marks each day ✓ complete / ✗ missed /
/// future. Only days from [firstRequiredDay] onward count as missed.
export const buildMonthHistory = (completeDays, year, month, firstRequiredDay, todayKey) => {
  const set = completeDays instanceof Set ? completeDays : new Set(completeDays || []);
  const pad = (n) => String(n).padStart(2, '0');
  const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
  const days = [];
  for (let d = 1; d <= daysInMonth; d++) {
    const key = `${year}-${pad(month)}-${pad(d)}`;
    let state = 'future';
    if (key < todayKey) {
      state = set.has(key) ? 'complete' : 'missed';
      if (firstRequiredDay && key < firstRequiredDay) state = 'none'; // before streak/join
    } else if (key === todayKey) {
      state = 'today';
    }
    days.push({ dateKey: key, day: d, state });
  }
  return days;
};

/// Relative time label helper for feeds (English; UI localizes if needed).
export const relativeTime = (date, now = new Date()) => {
  const s = Math.max(0, Math.floor((now - date) / 1000));
  if (s < 60) return 'just now';
  const m = Math.floor(s / 60);
  if (m < 60) return `${m} min ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.floor(h / 24);
  if (d < 7) return `${d}d ago`;
  return date.toISOString().slice(0, 10);
};

// ─────────────────────────────────────────────────────────────────────────
// GRACE PERIOD (Fix 1) — a prayer day stays open until Fajr of the next
// calendar day (fallback 4:00 AM local when the exact Fajr minute is not
// known server-side). Between midnight and Fajr:
//  - streak derivation anchors on YESTERDAY (the day is still in progress)
//  - a new tick is attributed to YESTERDAY's log when yesterday is
//    incomplete (so a late Isha at 00:30 finishes the previous day)
//  - when yesterday is already complete, the tick starts the new day.
// ─────────────────────────────────────────────────────────────────────────

export const GRACE_FALLBACK_MINUTES = 4 * 60; // 4:00 AM local

/// Minutes since local midnight of `now` in `timezone` (IANA id).
export const localMinutesInTz = (timezone, now = new Date()) => {
  try {
    const parts = new Intl.DateTimeFormat('en-GB', {
      timeZone: timezone || 'Asia/Karachi',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    }).formatToParts(now);
    const hour = Number(parts.find((p) => p.type === 'hour')?.value ?? 0);
    const minute = Number(parts.find((p) => p.type === 'minute')?.value ?? 0);
    return hour * 60 + minute;
  } catch (_) {
    return now.getUTCHours() * 60 + now.getUTCMinutes();
  }
};

/// Whether the clock is inside the grace window (midnight → Fajr).
export const inGraceWindow = (timezone, now = new Date(), fajrMinutes = GRACE_FALLBACK_MINUTES) =>
  localMinutesInTz(timezone, now) < fajrMinutes;

/// The active prayer day for STREAK DERIVATION and history: during the
/// grace window the previous calendar day is still "in progress".
export const activePrayerDayKey = (timezone, now = new Date(), fajrMinutes = GRACE_FALLBACK_MINUTES) => {
  const today = todayKeyInTz(timezone, now);
  return inGraceWindow(timezone, now, fajrMinutes) ? previousDateKey(today) : today;
};

/// The dateKey a TICK is written to. Same as the active prayer day, except
/// during grace when YESTERDAY is incomplete — then the tick finishes
/// yesterday. When yesterday is already complete the tick opens today.
export const tickTargetDayKey = (
  timezone,
  now,
  yesterdayIncomplete,
  fajrMinutes = GRACE_FALLBACK_MINUTES,
) => {
  const active = activePrayerDayKey(timezone, now, fajrMinutes);
  const today = todayKeyInTz(timezone, now);
  if (active === today) return today;
  return yesterdayIncomplete ? active : today;
};

// ─────────────────────────────────────────────────────────────────────────
// GHOST-MEMBER EXCLUSION (Fix 2a) — a member with ZERO completed prayers
// for GHOST_WINDOW_DAYS consecutive days no longer blocks the group day.
// Any tick brings them back into the requirement immediately.
// ─────────────────────────────────────────────────────────────────────────

export const GHOST_WINDOW_DAYS = 3;

/// `recentCounts`: completedCount values for the last GHOST_WINDOW_DAYS
/// calendar days (missing days count as 0). `eligibleDays`: how many of
/// those days the member was actually eligible on (new joiners who were
/// never required cannot be ghosts).
export const isGhostExcluded = (recentCounts, eligibleDays = GHOST_WINDOW_DAYS) => {
  if (eligibleDays < GHOST_WINDOW_DAYS) return false; // not yet subject to the rule
  return (recentCounts || []).every((c) => (Number(c) || 0) === 0);
};

// ─────────────────────────────────────────────────────────────────────────
// WEEKLY GROUP SHIELD (Fix 2b) — one automatic save per week: when a day
// ENDS (grace expired) with ≥80% of the required members at 5/5, the day
// is marked complete and the streak continues. 1 shield per week (Mon-Sun).
// ─────────────────────────────────────────────────────────────────────────

export const SHIELD_MIN_RATIO = 0.8;

/// Monday-start week key ('YYYY-MM-DD' of that week's Monday) for a dateKey.
const pad2 = (n) => String(n).padStart(2, '0');
export const weekKeyOf = (dateKey) => {
  const [y, m, d] = String(dateKey).split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d));
  const mondayOffset = (dt.getUTCDay() + 6) % 7; // Mon=0 … Sun=6
  dt.setUTCDate(dt.getUTCDate() - mondayOffset);
  return `${dt.getUTCFullYear()}-${pad2(dt.getUTCMonth() + 1)}-${pad2(dt.getUTCDate())}`;
};

/// A missed (ended) day qualifies for the shield when at least
/// SHIELD_MIN_RATIO of the required members finished 5/5 — but not ALL of
/// them (all-complete days are regular group days, never shields).
export const shieldQualifies = (requiredCount, completeCount) => {
  if (!requiredCount || requiredCount <= 0) return false;
  if (completeCount >= requiredCount) return false; // fully complete — not a shield case
  return completeCount / requiredCount >= SHIELD_MIN_RATIO;
};
