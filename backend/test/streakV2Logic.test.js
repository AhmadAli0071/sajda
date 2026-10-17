import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  GROUP_MEMBER_LIMIT_DEFAULT,
  randomCode,
  newGroupId,
  effectiveFromForJoin,
  isMemberEligibleOn,
  isGroupDaySatisfied,
  dayCompleteFromCount,
  currentRunFromDays,
  longestRunFromDays,
  buildMonthHistory,
  relativeTime,
  applyDailyStreakRules,
  GRACE_FALLBACK_MINUTES,
  localMinutesInTz,
  inGraceWindow,
  activePrayerDayKey,
  tickTargetDayKey,
  GHOST_WINDOW_DAYS,
  isGhostExcluded,
  SHIELD_MIN_RATIO,
  weekKeyOf,
  shieldQualifies,
} from '../backend/services/streakV2Logic.js';
import { todayKeyInTz, nextDateKey, previousDateKey } from '../backend/services/streakLogic.js';

// ---------------------------------------------------------------------------
// NEW-MEMBER RULE: a member joining today only counts from the NEXT day —
// they can never retroactively break an existing group streak.
// ---------------------------------------------------------------------------

test('effectiveFromForJoin returns TOMORROW in the group timezone', () => {
  // 2026-09-06 10:00 UTC == 15:00 Karachi — join "today" = 2026-09-06
  const now = new Date(Date.UTC(2026, 8, 6, 10, 0));
  assert.equal(effectiveFromForJoin(now, 'Asia/Karachi'), '2026-09-07');
});

test('a join just before group midnight is effective the next group day', () => {
  // 2026-09-06 18:59 UTC == 23:59 Karachi (one minute before midnight)
  const now = new Date(Date.UTC(2026, 8, 6, 18, 59));
  assert.equal(effectiveFromForJoin(now, 'Asia/Karachi'), '2026-09-07');
  // one minute later it is already Sep 7 in Karachi → effective Sep 8
  const afterMidnight = new Date(Date.UTC(2026, 8, 6, 19, 1));
  assert.equal(effectiveFromForJoin(afterMidnight, 'Asia/Karachi'), '2026-09-08');
});

test('isMemberEligibleOn respects effectiveFromDate and status', () => {
  const member = { status: 'active', effectiveFromDate: '2026-09-07' };
  assert.equal(isMemberEligibleOn(member, '2026-09-06'), false); // join day: not required
  assert.equal(isMemberEligibleOn(member, '2026-09-07'), true);  // from next day
  assert.equal(isMemberEligibleOn(member, '2026-09-10'), true);
  assert.equal(isMemberEligibleOn({ ...member, status: 'left' }, '2026-09-10'), false);
  assert.equal(isMemberEligibleOn(null, '2026-09-10'), false);
});

// ---------------------------------------------------------------------------
// GROUP DAY COMPLETION — ALL eligible active members must be 5/5.
// ---------------------------------------------------------------------------

test('group day completes only when EVERY eligible member is complete', () => {
  const members = [
    { userId: 'u1', status: 'active', effectiveFromDate: '2026-09-01' },
    { userId: 'u2', status: 'active', effectiveFromDate: '2026-09-01' },
    { userId: 'u3', status: 'active', effectiveFromDate: '2026-09-01' },
  ];
  const rows = (ids) => ids.map((id) => ({ userId: id, isDayComplete: true }));
  assert.equal(isGroupDaySatisfied(members, rows(['u1', 'u2', 'u3'])), true);
  assert.equal(isGroupDaySatisfied(members, rows(['u1', 'u2'])), false); // u3 at 4/5
  assert.equal(isGroupDaySatisfied(members, rows(['u1'])), false);
  assert.equal(isGroupDaySatisfied(members, []), false);
});

test('missing progress rows count as incomplete', () => {
  const members = [{ userId: 'u1', status: 'active' }];
  assert.equal(isGroupDaySatisfied(members, [{ userId: 'u2', isDayComplete: true }]), false);
});

test('a member who joined today is NOT required for today', () => {
  const members = [
    { userId: 'u1', status: 'active', effectiveFromDate: '2026-09-01' },
    { userId: 'new', status: 'active', effectiveFromDate: '2026-09-07' },
  ];
  // Only u1 is eligible on 09-06; u1 complete → day satisfied even though
  // the new member (who joins ON 09-06) has no progress yet.
  const eligible = members.filter((m) => isMemberEligibleOn(m, '2026-09-06'));
  assert.equal(isGroupDaySatisfied(eligible, [{ userId: 'u1', isDayComplete: true }]), true);
});

test('empty group never completes a day', () => {
  assert.equal(isGroupDaySatisfied([], []), false);
});

// ---------------------------------------------------------------------------
// STREAK RUNS — derived from completed-day records (no ++ from a tap).
// ---------------------------------------------------------------------------

test('current run counts consecutive complete days with yesterday grace', () => {
  const days = new Set(['2026-09-04', '2026-09-05', '2026-09-06']);
  // today = 09-07, still 3/5 → streak alive via yesterday
  let r = currentRunFromDays(days, '2026-09-07');
  assert.equal(r.run, 3);
  assert.equal(r.startDate, '2026-09-04');
  // today complete too → 4
  r = currentRunFromDays(new Set([...days, '2026-09-07']), '2026-09-07');
  assert.equal(r.run, 4);
});

test('a missed day breaks the current run', () => {
  const days = new Set(['2026-09-01', '2026-09-02', '2026-09-03', '2026-09-06', '2026-09-07']);
  // gap on 09-04/05 → current run = 2 (09-06..09-07 via yesterday grace today=09-08)
  const r = currentRunFromDays(days, '2026-09-08');
  assert.equal(r.run, 2);
  assert.equal(r.startDate, '2026-09-06');
});

test('empty history → zero run', () => {
  const r = currentRunFromDays(new Set(), '2026-09-08');
  assert.equal(r.run, 0);
  assert.equal(r.startDate, null);
});

test('longest run spans whole history and ignores duplicate keys', () => {
  const days = ['2026-09-01', '2026-09-02', '2026-09-03', '2026-09-05', '2026-09-06', '2026-09-02'];
  assert.equal(longestRunFromDays(new Set(days)), 3);
  assert.equal(longestRunFromDays([]), 0);
  assert.equal(longestRunFromDays(['2026-09-01']), 1);
});

// ---------------------------------------------------------------------------
// HISTORY CALENDAR — ✓ complete / ✗ missed / future / today / none.
// ---------------------------------------------------------------------------

test('buildMonthHistory marks complete, missed, today, future and pre-join days', () => {
  const days = new Set(['2026-09-01', '2026-09-02', '2026-09-04']);
  const cal = buildMonthHistory(days, 2026, 9, '2026-09-01', '2026-09-05');
  const byDay = Object.fromEntries(cal.map((d) => [d.day, d.state]));
  assert.equal(byDay[1], 'complete');
  assert.equal(byDay[3], 'missed');   // after first required day, not complete
  assert.equal(byDay[4], 'complete');
  assert.equal(byDay[5], 'today');
  assert.equal(byDay[6], 'future');
});

test('days before the first required day are marked none (not missed)', () => {
  const cal = buildMonthHistory(new Set(['2026-09-03']), 2026, 9, '2026-09-03', '2026-09-05');
  const byDay = Object.fromEntries(cal.map((d) => [d.day, d.state]));
  assert.equal(byDay[1], 'none');
  assert.equal(byDay[2], 'none');
  assert.equal(byDay[4], 'missed'); // after streak started but not completed
});

// ---------------------------------------------------------------------------
// CODES & IDS
// ---------------------------------------------------------------------------

test('invite codes use the unambiguous alphabet and requested length', () => {
  const code = randomCode(6);
  assert.equal(code.length, 6);
  assert.match(code, /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]+$/);
  const codes = new Set(Array.from({ length: 200 }, () => randomCode(6)));
  assert.ok(codes.size > 190, 'codes should be near-unique');
});

test('group ids have the grp_ prefix', () => {
  assert.match(newGroupId(), /^grp_[a-z0-9]{10}$/);
});

test('member limit is a single configurable constant', () => {
  assert.ok(Number.isInteger(GROUP_MEMBER_LIMIT_DEFAULT) && GROUP_MEMBER_LIMIT_DEFAULT >= 10);
});

test('relativeTime buckets sensibly', () => {
  const now = new Date('2026-09-07T12:00:00Z');
  assert.equal(relativeTime(new Date('2026-09-07T11:59:40Z'), now), 'just now');
  assert.equal(relativeTime(new Date('2026-09-07T11:30:00Z'), now), '30 min ago');
  assert.equal(relativeTime(new Date('2026-09-07T09:00:00Z'), now), '3h ago');
});

// ---------------------------------------------------------------------------
// Calendar-day helpers re-verified in the group context (group timezone).
// ---------------------------------------------------------------------------

test('group dateKey uses the GROUP timezone, not the actor device clock', () => {
  const instant = new Date(Date.UTC(2026, 8, 6, 20, 0)); // 20:00 UTC
  assert.equal(todayKeyInTz('Asia/Karachi', instant), '2026-09-07'); // +5 → 01:00 next day
  assert.equal(todayKeyInTz('America/New_York', instant), '2026-09-06'); // -4 → 16:00
  assert.equal(previousDateKey(todayKeyInTz('Asia/Karachi', instant)), '2026-09-06');
  assert.equal(nextDateKey(previousDateKey('2026-09-07')), '2026-09-07');
});

// ---------------------------------------------------------------------------
// DAILY STREAK RULES (applyDailyStreakRules):
//   same day -> intact | consecutive day -> +1 | missed >= 2 days -> reset 1
// ---------------------------------------------------------------------------

test('applyDailyStreakRules: SAME DAY keeps the current streak intact', () => {
  assert.equal(applyDailyStreakRules(7, '2026-09-07', '2026-09-07'), 7);
  assert.equal(applyDailyStreakRules(1, '2026-09-07', '2026-09-07'), 1);
  // Even repeated ticks on the same day never double-increment.
  assert.equal(applyDailyStreakRules(applyDailyStreakRules(7, '2026-09-07', '2026-09-07'), '2026-09-07', '2026-09-07'), 7);
});

test('applyDailyStreakRules: CONSECUTIVE day increments by +1', () => {
  assert.equal(applyDailyStreakRules(7, '2026-09-06', '2026-09-07'), 8);
  assert.equal(applyDailyStreakRules(0, '2026-09-06', '2026-09-07'), 1);
});

test('applyDailyStreakRules: MISSED day (gap >= 2) resets to 1', () => {
  // one full day skipped: last active Sep 5, today Sep 7
  assert.equal(applyDailyStreakRules(30, '2026-09-05', '2026-09-07'), 1);
  assert.equal(applyDailyStreakRules(30, '2026-08-01', '2026-09-07'), 1);
});

test('applyDailyStreakRules: first ever day starts a streak of 1', () => {
  assert.equal(applyDailyStreakRules(0, null, '2026-09-07'), 1);
  assert.equal(applyDailyStreakRules(0, '', '2026-09-07'), 1);
});

test('applyDailyStreakRules agrees with the derived-run model', () => {
  // The set-based walk (currentRunFromDays) and the counter rules must
  // agree: a 3-day complete run ending yesterday, today not yet done.
  const days = new Set(['2026-09-04', '2026-09-05', '2026-09-06']);
  const { run } = currentRunFromDays(days, '2026-09-07');
  assert.equal(run, 3);
  // Counter model: last completed day is yesterday -> consecutive +1 from a
  // 2-day streak would be 3. Both models agree.
  assert.equal(applyDailyStreakRules(2, '2026-09-06', '2026-09-07'), 3);
  // If yesterday was MISSED (streak broke), today's completion must reset:
  assert.equal(applyDailyStreakRules(3, '2026-09-05', '2026-09-07'), 1);
  const broken = new Set(['2026-09-01', '2026-09-02', '2026-09-03', '2026-09-04']);
  assert.equal(currentRunFromDays(broken, '2026-09-07').run, 0); // today not yet complete, yesterday missed
});

// ---------------------------------------------------------------------------
// DAY-COMPLETION IS DERIVED — a day counts as complete ONLY at 5/5.
// Regression: the tick endpoint once took isDayComplete from the request's
// `completed` flag, so ONE prayer tick marked the whole day (and the group
// day) complete. dayCompleteFromCount is the single source of truth.
// ---------------------------------------------------------------------------

test('dayCompleteFromCount: a single prayer tick must NOT complete the day', () => {
  assert.equal(dayCompleteFromCount(0), false);
  assert.equal(dayCompleteFromCount(1), false);
  assert.equal(dayCompleteFromCount(2), false);
  assert.equal(dayCompleteFromCount(3), false);
  assert.equal(dayCompleteFromCount(4), false);
  assert.equal(dayCompleteFromCount(5), true); // all five prayers
});

test('dayCompleteFromCount tolerates null/garbage counts', () => {
  assert.equal(dayCompleteFromCount(null), false);
  assert.equal(dayCompleteFromCount(undefined), false);
  assert.equal(dayCompleteFromCount('3'), false);
  assert.equal(dayCompleteFromCount('5'), true);
});

// ---------------------------------------------------------------------------
// GRACE PERIOD (Fix 1) — the day stays open until Fajr (fallback 4:00 AM
// local). Streak derivation anchors on yesterday during grace; ticks are
// attributed to yesterday when yesterday is incomplete.
// ---------------------------------------------------------------------------

test('localMinutesInTz and inGraceWindow use the LOCAL clock', () => {
  // 2026-09-06 20:30 UTC == 2026-09-07 01:30 Karachi (+5)
  const instant = new Date(Date.UTC(2026, 8, 6, 20, 30));
  assert.equal(localMinutesInTz('Asia/Karachi', instant), 90); // 01:30
  assert.equal(inGraceWindow('Asia/Karachi', instant), true);
  assert.equal(localMinutesInTz('America/New_York', instant), 16 * 60 + 30); // 16:30
  assert.equal(inGraceWindow('America/New_York', instant), false);
});

test('activePrayerDayKey anchors on YESTERDAY during grace', () => {
  const instant = new Date(Date.UTC(2026, 8, 6, 20, 30)); // 01:30 Sep 7 Karachi
  assert.equal(activePrayerDayKey('Asia/Karachi', instant), '2026-09-06');
  // Past Fajr (fallback 4:00 AM): the new day owns the key
  const afterFajr = new Date(Date.UTC(2026, 8, 6, 23, 30)); // 04:30 Sep 7 Karachi
  assert.equal(activePrayerDayKey('Asia/Karachi', afterFajr), '2026-09-07');
});

test('tickTargetDayKey: late tick finishes YESTERDAY when it is incomplete', () => {
  const instant = new Date(Date.UTC(2026, 8, 6, 20, 30)); // 01:30 Sep 7 Karachi
  // Yesterday incomplete → tick belongs to Sep 6
  assert.equal(tickTargetDayKey('Asia/Karachi', instant, true), '2026-09-06');
  // Yesterday complete → tick opens Sep 7
  assert.equal(tickTargetDayKey('Asia/Karachi', instant, false), '2026-09-07');
});

test('tickTargetDayKey outside grace always targets the calendar day', () => {
  const instant = new Date(Date.UTC(2026, 8, 6, 12, 0)); // 17:00 Sep 6 Karachi
  assert.equal(tickTargetDayKey('Asia/Karachi', instant, true), '2026-09-06');
  assert.equal(tickTargetDayKey('Asia/Karachi', instant, false), '2026-09-06');
});

test('GRACE_FALLBACK_MINUTES is 4:00 AM', () => {
  assert.equal(GRACE_FALLBACK_MINUTES, 240);
});

// ---------------------------------------------------------------------------
// GHOST-MEMBER EXCLUSION (Fix 2a) — 0 activity for the full window means
// the member no longer blocks the group day. New joiners (not yet subject
// to the rule) are never ghosts.
// ---------------------------------------------------------------------------

test('isGhostExcluded: zero activity across the window → ghost', () => {
  assert.equal(isGhostExcluded([0, 0, 0]), true);
  assert.equal(isGhostExcluded([0, 0, 0, 0]), true);
});

test('isGhostExcluded: ANY recent activity keeps the member required', () => {
  assert.equal(isGhostExcluded([1, 0, 0]), false);
  assert.equal(isGhostExcluded([0, 3, 0]), false);
  assert.equal(isGhostExcluded([0, 0, 5]), false);
});

test('isGhostExcluded: new joiners (few eligible days) are never ghosts', () => {
  assert.equal(isGhostExcluded([0], 1), false);
  assert.equal(isGhostExcluded([0, 0], 2), false);
  assert.equal(isGhostExcluded([], 0), false);
});

test('GHOST_WINDOW_DAYS is 3', () => {
  assert.equal(GHOST_WINDOW_DAYS, 3);
});

// ---------------------------------------------------------------------------
// WEEKLY GROUP SHIELD (Fix 2b) — one automatic save per week when a missed
// day still had ≥80% of required members at 5/5.
// ---------------------------------------------------------------------------

test('weekKeyOf returns the Monday of the week containing the dateKey', () => {
  assert.equal(weekKeyOf('2026-09-07'), '2026-09-07'); // Monday itself
  assert.equal(weekKeyOf('2026-09-12'), '2026-09-07'); // Saturday → that Monday
  assert.equal(weekKeyOf('2026-09-13'), '2026-09-07'); // Sunday → SAME week (Mon-Sun)
  assert.equal(weekKeyOf('2026-09-14'), '2026-09-14'); // next Monday → new week
  assert.equal(weekKeyOf('2026-09-06'), '2026-08-31'); // Sunday belongs to prior week
});

test('shieldQualifies: ≥80% of required members complete on an otherwise missed day', () => {
  // 4 required, 3 complete → 75% → NO
  assert.equal(shieldQualifies(4, 3), false);
  // 5 required, 4 complete → 80% → YES
  assert.equal(shieldQualifies(5, 4), true);
  // 10 required, 8 complete → 80% → YES
  assert.equal(shieldQualifies(10, 8), true);
  // 5 required, 5 complete → fully complete, NOT a shield case
  assert.equal(shieldQualifies(5, 5), false);
  // Degenerate inputs
  assert.equal(shieldQualifies(0, 0), false);
  assert.equal(shieldQualifies(1, 0), false); // 0/1 = 0% → NO
});

test('SHIELD_MIN_RATIO is 0.8', () => {
  assert.equal(SHIELD_MIN_RATIO, 0.8);
});
