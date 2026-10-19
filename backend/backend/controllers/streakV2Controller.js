import mongoose from 'mongoose';
import jwt from 'jsonwebtoken';
import { timingSafeEqual } from 'node:crypto';
import User from '../models/User.js';
import SoloStreak from '../models/SoloStreak.js';
import SoloDailyProgress from '../models/SoloDailyProgress.js';
import Group from '../models/Group.js';
import GroupMember from '../models/GroupMember.js';
import GroupDailyProgress from '../models/GroupDailyProgress.js';
import GroupDailySummary from '../models/GroupDailySummary.js';
import GroupActivity from '../models/GroupActivity.js';
import JoinRequest from '../models/JoinRequest.js';
import PushToken from '../models/PushToken.js';
import { PRAYERS, todayKeyInTz, previousDateKey } from '../services/streakLogic.js';
import { pushToUsers } from '../services/fcm.js';
import { getJwtSecret } from '../middleware/auth.js';
import {
  GROUP_MEMBER_LIMIT_DEFAULT,
  GROUP_NAME_MAX,
  ACTIVITY_PAGE_SIZE,
  DISCOVER_PAGE_SIZE,
  randomCode,
  newGroupId,
  effectiveFromForJoin,
  isMemberEligibleOn,
  isGroupDaySatisfied,
  currentRunFromDays,
  longestRunFromDays,
  buildMonthHistory,
  activePrayerDayKey,
  tickTargetDayKey,
  inGraceWindow,
  isGhostExcluded,
  weekKeyOf,
  shieldQualifies,
  GHOST_WINDOW_DAYS,
} from '../services/streakV2Logic.js';

const fail = (res, status, code, message) =>
  res.status(status).json({ success: false, code, message });

const PRAYER_LABELS = {
  fajr: 'Fajr',
  dhuhr: 'Dhuhr',
  asr: 'Asr',
  maghrib: 'Maghrib',
  isha: 'Isha',
};

const resolveUser = async (req) => {
  const id = String(req.user?.id || req.user?._id);
  let displayName = req.user?.displayName || req.user?.name || 'Anonymous';
  let timezone = req.user?.timezone || 'Asia/Karachi';
  try {
    const u = await User.findById(id).select('displayName timezone notificationsSeenAt').lean();
    if (u) {
      if (u.displayName) displayName = u.displayName;
      if (u.timezone) timezone = u.timezone;
    }
  } catch (_) { /* token fallback */ }
  return { id, displayName, timezone };
};

const prayerOf = (raw) => String(raw || '').trim().toLowerCase();

// ─────────────────────────────────────────────────────────────────────────
// STREAK DERIVATION — streaks are computed from daily records, never
// incremented by a tap. Bounded walk: cost = current streak length.
// The walk anchors on the ACTIVE PRAYER DAY (grace-aware): between
// midnight and Fajr the previous day is still in progress, so the streak
// is never reset during the grace window.
// ─────────────────────────────────────────────────────────────────────────

const rollForwardSolo = async (solo, userId, timezone) => {
  const today = activePrayerDayKey(timezone);
  // Bounded read: the CURRENT run cannot start before the recorded start
  // date, so the walk only needs those rows. bestStreak is monotonic —
  // max(stored, current run) needs no full-history scan. When no start date
  // exists yet (first run / post-reset) the query is unbounded exactly once;
  // the run it produces sets the start date and every later read is bounded.
  const since = solo?.currentStreakStartDate || null;
  const rows = await SoloDailyProgress.find({
    userId,
    isDayComplete: true,
    ...(since ? { dateKey: { $gte: since } } : {}),
  }).select('dateKey').lean();
  const days = new Set(rows.map((r) => r.dateKey));
  const { run, startDate } = currentRunFromDays(days, today);
  let doc = solo;
  if (!doc) doc = await SoloStreak.create({ userId });
  const best = Math.max(doc.bestStreak || 0, run);
  let changed = false;
  if (doc.currentStreak !== run) { doc.currentStreak = run; changed = true; }
  if (doc.bestStreak !== best) { doc.bestStreak = best; changed = true; }
  if (doc.currentStreakStartDate !== startDate) { doc.currentStreakStartDate = startDate; changed = true; }
  const last = [...days].sort().pop() || null;
  if (doc.lastCompletedDay !== last) { doc.lastCompletedDay = last; changed = true; }
  if (doc.lastEvaluatedDay !== today) { doc.lastEvaluatedDay = today; changed = true; }
  if (changed) await doc.save();
  return doc;
};

// Ghost exclusion (Fix 2a): a member with ZERO completed prayers for the
// last GHOST_WINDOW_DAYS days no longer blocks the group day. Any tick
// brings them back into the requirement immediately. Returns the
// non-ghost subset of `members` (each needs userId + effectiveFromDate).
const ghostFreeMembers = async (groupId, dateKey, members) => {
  if (!members || members.length === 0) return [];
  const keys = [dateKey];
  let k = dateKey;
  for (let i = 1; i < GHOST_WINDOW_DAYS; i++) {
    k = previousDateKey(k);
    keys.push(k);
  }
  const rows = await GroupDailyProgress.find({ groupId, dateKey: { $in: keys } })
    .select('userId dateKey completedCount').lean();
  const countBy = new Map(); // `${userId}:${dateKey}` -> completedCount
  for (const r of rows) countBy.set(`${r.userId}:${r.dateKey}`, r.completedCount || 0);
  return members.filter((m) => {
    const uid = String(m.userId);
    const counts = keys.map((key) => countBy.get(`${uid}:${key}`) || 0);
    // Only members who were eligible for the WHOLE window can be ghosts —
    // a brand-new joiner with no rows is not a ghost.
    let eligibleDays = 0;
    for (const key of keys) if (String(m.effectiveFromDate || '') <= key) eligibleDays++;
    return !isGhostExcluded(counts, eligibleDays);
  });
};

// Weekly group shield (Fix 2b): called for the day that just ENDED (grace
// expired). If ≥80% of the required (ghost-free) members finished 5/5 but
// some did not, the day is auto-completed (shielded) so the streak
// survives — once per week (Mon–Sun), tracked on Group.shieldUsedWeekKey.
const maybeApplyGroupShield = async (group, dateKey) => {
  try {
    const weekKey = weekKeyOf(dateKey);
    if (group.shieldUsedWeekKey === weekKey) return false; // already used this week
    const members = await GroupMember.find({
      groupId: group.groupId, status: 'active', effectiveFromDate: { $lte: dateKey },
    }).select('userId effectiveFromDate').lean();
    const required = await ghostFreeMembers(group.groupId, dateKey, members);
    if (required.length === 0) return false;
    const rows = await GroupDailyProgress.find({ groupId: group.groupId, dateKey })
      .select('userId isDayComplete').lean();
    const completeIds = new Set(rows.filter((r) => r.isDayComplete).map((r) => String(r.userId)));
    const completeCount = required.filter((m) => completeIds.has(String(m.userId))).length;
    if (!shieldQualifies(required.length, completeCount)) return false;

    const updated = await GroupDailySummary.findOneAndUpdate(
      { groupId: group.groupId, dateKey, isGroupDayComplete: false },
      {
        $setOnInsert: { groupId: group.groupId, dateKey },
        $set: {
          isGroupDayComplete: true,
          shielded: true,
          completedAt: new Date(),
          eligibleCount: required.length,
          completedCount: completeCount,
        },
      },
      { upsert: true, new: true },
    );
    if (!updated) return false;
    group.shieldUsedWeekKey = weekKey;
    await group.save();
    await GroupActivity.create({
      groupId: group.groupId,
      userId: group.ownerId,
      displayName: 'Group Shield',
      type: 'group_shield_used',
      dateKey,
    });
    // Fire-and-forget: tell everyone the shield saved the streak.
    (async () => {
      try {
        const membersAll = await GroupMember.find({ groupId: group.groupId, status: 'active' })
          .select('userId').lean();
        await pushToUsers(membersAll.map((m) => m.userId), {
          title: `${group.name} — shield used 🛡️`,
          body: `Most of you finished all five prayers. The missed day was saved — the streak lives on!`,
          data: { type: 'group_shield_used', groupId: group.groupId },
        });
      } catch (e) {
        console.warn('[streak] shield push failed:', e.message);
      }
    })();
    return true;
  } catch (e) {
    console.warn('[streak] group shield failed:', e.message);
    return false;
  }
};

const rollForwardGroup = async (group) => {
  const today = activePrayerDayKey(group.timezone);
  // Same bounded read as the solo roll-forward — see the rationale there.
  const since = group.currentStreakStartDate || null;
  const rows = await GroupDailySummary.find({
    groupId: group.groupId,
    isGroupDayComplete: true,
    ...(since ? { dateKey: { $gte: since } } : {}),
  }).select('dateKey').lean();
  const days = new Set(rows.map((r) => r.dateKey));
  let { run, startDate } = currentRunFromDays(days, today);

  // Weekly group shield (Fix 2b): the day BEFORE the active day just
  // ended. If it was missed but ≥80% of the required members finished 5/5
  // and the weekly shield is unused, mark it complete and keep the streak.
  const endedDay = previousDateKey(today);
  if (!days.has(endedDay)) {
    const shielded = await maybeApplyGroupShield(group, endedDay);
    if (shielded) {
      days.add(endedDay);
      ({ run, startDate } = currentRunFromDays(days, today));
    }
  }

  const best = Math.max(group.bestStreak || 0, run);
  let changed = false;
  if (group.currentStreak !== run) { group.currentStreak = run; changed = true; }
  if (group.bestStreak !== best) { group.bestStreak = best; changed = true; }
  if (group.currentStreakStartDate !== startDate) { group.currentStreakStartDate = startDate; changed = true; }
  if (group.lastEvaluatedDay !== today) { group.lastEvaluatedDay = today; changed = true; }
  if (changed) await group.save();
  return group;
};

const soloPayload = (solo, todayRow) => ({
  started: true,
  currentStreak: solo?.currentStreak || 0,
  bestStreak: solo?.bestStreak || 0,
  currentStreakStartDate: solo?.currentStreakStartDate || null,
  lastCompletedDay: solo?.lastCompletedDay || null,
  today: {
    fajr: !!todayRow?.fajr,
    dhuhr: !!todayRow?.dhuhr,
    asr: !!todayRow?.asr,
    maghrib: !!todayRow?.maghrib,
    isha: !!todayRow?.isha,
    completedCount: todayRow?.completedCount || 0,
    isDayComplete: !!todayRow?.isDayComplete,
  },
});

// ─────────────────────────────────────────────────────────────────────────
// PRAYER COMPLETION — ONE canonical action. Updates Solo + every group +
// activity, idempotent per (context, user, dateKey, prayer).
// ─────────────────────────────────────────────────────────────────────────

const PRAYERS_TOTAL = PRAYERS.length;

// ONE roundtrip: flips the prayer flag only when it actually changes,
// keeps completedCount truthful, creates the row on the first tick of the
// day (upsert), and returns the row — null when nothing matched (re-tick,
// or un-tick with no row).
const flipPrayer = async (Model, filter, prayer, completed, insertExtras = {}) => {
  const match = { ...filter, [prayer]: completed ? { $ne: true } : true };
  const update = completed
    ? {
        // NOTE: completedCount must NOT appear here — $inc below already
        // creates it as 1 on insert, and Mongo rejects the same path in
        // two update operators ("Updating the path 'completedCount' would
        // create a conflict at 'completedCount'").
        $setOnInsert: { ...filter, ...insertExtras },
        $set: { [prayer]: true },
        $inc: { completedCount: 1 },
      }
    : { $set: { [prayer]: false }, $inc: { completedCount: -1 } };
  return Model.findOneAndUpdate(match, update, { upsert: completed, new: true }).lean();
};

// Day-complete is DERIVED — a day counts as complete only when ALL five
// prayers are ticked, never from the request's completed flag (a single
// tick must never complete the day). Pipeline update keeps the derivation
// atomic with the write.
const syncDayComplete = async (Model, filter) => {
  return Model.findOneAndUpdate(
    filter,
    [
      {
        $set: {
          isDayComplete: { $gte: [{ $ifNull: ['$completedCount', 0] }, PRAYERS_TOTAL] },
          completedAt: {
            $cond: {
              if: { $lt: [{ $ifNull: ['$completedCount', 0] }, PRAYERS_TOTAL] },
              then: '$$REMOVE',
              else: { $ifNull: ['$completedAt', '$$NOW'] },
            },
          },
        },
      },
    ],
    // Mongoose 9 requires an explicit opt-in for pipeline (array) updates.
    { new: true, updatePipeline: true },
  ).lean();
};

// Only the 5th tick (or an un-tick / repair of a complete day) can change
// day-completion — the rare path pays for the derived write.
const needsDaySync = (row) =>
  !!row && ((row.completedCount || 0) >= PRAYERS_TOTAL || row.isDayComplete === true);

// Checks ALL eligible active members (ghosts excluded — Fix 2a) and —
// only when everyone required is 5/5 — flips the summary COMPLETE exactly
// once (atomic conditional update).
const maybeCompleteGroupDay = async (group, dateKey, actor) => {
  const members = await GroupMember.find({
    groupId: group.groupId, status: 'active', effectiveFromDate: { $lte: dateKey },
  }).select('userId effectiveFromDate').lean();
  // Ghost exclusion: members with 0 activity for 3+ days don't block.
  const eligible = await ghostFreeMembers(group.groupId, dateKey, members);
  if (eligible.length === 0) return false;
  const rows = await GroupDailyProgress.find({ groupId: group.groupId, dateKey, eligible: true })
    .select('userId isDayComplete').lean();
  if (!isGroupDaySatisfied(eligible, rows)) return false;

  const updated = await GroupDailySummary.findOneAndUpdate(
    { groupId: group.groupId, dateKey, isGroupDayComplete: false },
    {
      $setOnInsert: { groupId: group.groupId, dateKey },
      $set: {
        isGroupDayComplete: true,
        completedAt: new Date(),
        eligibleCount: eligible.length,
        completedCount: rows.filter((r) => r.isDayComplete).length,
      },
    },
    { upsert: true, new: true },
  ).catch((e) => {
    if (e?.code === 11000) return null;
    throw e;
  });
  // The conditional update guarantees exactly one writer sees false→true,
  // but upsert races can still land here; verify the flip we own.
  if (!updated) return false;
  await GroupActivity.create({
    groupId: group.groupId,
    userId: actor?._id || actor,
    displayName: actor?.displayName || 'Someone',
    type: 'group_day_completed',
    dateKey,
  });
  await rollForwardGroup(group);
  return true;
};

const revertGroupDay = async (group, dateKey) => {
  const updated = await GroupDailySummary.findOneAndUpdate(
    { groupId: group.groupId, dateKey, isGroupDayComplete: true },
    { $set: { isGroupDayComplete: false }, $unset: { completedAt: '' } },
    { new: true },
  );
  if (!updated) return false;
  await GroupActivity.deleteOne({ groupId: group.groupId, type: 'group_day_completed', dateKey });
  await rollForwardGroup(group);
  return true;
};

export const completePrayer = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const prayer = prayerOf(req.body?.prayer);
    if (!PRAYERS.includes(prayer)) {
      return fail(res, 400, 'INVALID_PRAYER', 'Invalid prayer name');
    }
    const completed = req.body?.completed !== false; // default true
    // Dynamic Fajr grace cutoff (minutes since local midnight) from the
    // client's actual prayer times. Fallback 4:00 AM if not provided.
    const fajrMinutes = Math.max(60, Math.min(600,
      Number(req.body?.fajrMinutes) || undefined || 4 * 60));
    const now = new Date();

    // ── SOLO (flip + derived day-complete) ──
    // Grace attribution (Fix 1): between midnight and Fajr a tick belongs
    // to YESTERDAY when yesterday is still incomplete.
    const yKey = previousDateKey(todayKeyInTz(user.timezone));
    const yRow = await SoloDailyProgress.findOne({
      userId: user.id, dateKey: yKey,
    }).select('isDayComplete completedCount').lean();
    const yesterdayIncomplete = !yRow || (yRow.completedCount || 0) < PRAYERS.length;
    const soloKey = tickTargetDayKey(user.timezone, now, yesterdayIncomplete, fajrMinutes);

    // Untick lock (Fix 3): past days are read-only. The server computes
    // the dateKey itself (never from client input) and this guard makes
    // the rule explicit — days BEFORE the active prayer day cannot be
    // un-ticked. (The active day itself, including grace-attributed
    // yesterday ticks, remains editable.)
    if (!completed && soloKey < activePrayerDayKey(user.timezone, now, fajrMinutes)) {
      return fail(res, 409, 'PAST_DAY_READONLY', 'Past prayer days cannot be modified');
    }

    let solo = await SoloStreak.findOne({ userId: user.id });
    if (completed && !solo) solo = await SoloStreak.create({ userId: user.id });
    const soloRowFilter = { userId: new mongoose.Types.ObjectId(user.id), dateKey: soloKey };
    let soloRow = await flipPrayer(SoloDailyProgress, soloRowFilter, prayer, completed);
    if (!soloRow) {
      // Re-tick of an already-completed prayer (e.g. retrying after a
      // partial failure): still refresh day-completion so a stuck 5/5
      // row heals instead of silently staying incomplete.
      soloRow = await SoloDailyProgress.findOne(soloRowFilter).lean();
    }
    if (needsDaySync(soloRow)) {
      soloRow = await syncDayComplete(SoloDailyProgress, soloRowFilter);
    }
    solo = await rollForwardSolo(solo, user.id, user.timezone);

    // ── GROUPS — fan-out of the SAME single tick, groups in parallel ──
    const memberships = await GroupMember.find({ userId: user.id, status: 'active' }).lean();
    const groupIds = memberships.map((m) => m.groupId);
    const groups = groupIds.length
      ? await Group.find({ groupId: { $in: groupIds }, status: 'active' })
      : [];

    const tickGroup = async (group) => {
      // Per-group grace attribution uses the GROUP day boundary.
      const gYesterday = previousDateKey(todayKeyInTz(group.timezone));
      const gYRow = await GroupDailyProgress.findOne({
        groupId: group.groupId,
        userId: new mongoose.Types.ObjectId(user.id),
        dateKey: gYesterday,
      }).select('completedCount').lean();
      const gYesterdayIncomplete = !gYRow || (gYRow.completedCount || 0) < PRAYERS.length;
      const gKey = tickTargetDayKey(group.timezone, now, gYesterdayIncomplete, fajrMinutes);
      const membership = memberships.find((m) => m.groupId === group.groupId);
      const eligible = isMemberEligibleOn(membership, gKey);
      const rowFilter = { groupId: group.groupId, userId: new mongoose.Types.ObjectId(user.id), dateKey: gKey };
      let dayCompleted = false;
      if (completed) {
        let row = await flipPrayer(GroupDailyProgress, rowFilter, prayer, true, { eligible });
        if (!row) {
          // Re-tick retry: heal a row that reached 5/5 while a later step failed.
          row = await GroupDailyProgress.findOne(rowFilter).lean();
        }
        const freshRow = needsDaySync(row)
          ? await syncDayComplete(GroupDailyProgress, rowFilter)
          : row;
        // Only a member who just finished 5/5 can complete the group day —
        // no point re-checking every member on each of the first four ticks.
        dayCompleted = eligible && freshRow?.isDayComplete === true
          ? await maybeCompleteGroupDay(group, gKey, { _id: user.id, displayName: user.displayName })
          : false;
      } else {
        // Untick lock (Fix 3): only the active prayer day of THIS group.
        if (gKey < activePrayerDayKey(group.timezone, now, fajrMinutes)) {
          return {
            groupId: group.groupId,
            name: group.name,
            dateKey: gKey,
            currentStreak: group.currentStreak,
          };
        }
        const row = await flipPrayer(GroupDailyProgress, rowFilter, prayer, false);
        if (row?.isDayComplete) await syncDayComplete(GroupDailyProgress, rowFilter);
        if (eligible) await revertGroupDay(group, gKey);
      }

      // ── Real-time FCM (fire-and-forget; the tick NEVER depends on it) ──
      // NOTE: runs after the tick settles — `group.currentStreak` below is
      // the value possibly refreshed by rollForwardGroup just above.
      const actorName = user.displayName || 'A member';
      (async () => {
        try {
          const members = await GroupMember.find({ groupId: group.groupId, status: 'active' })
            .select('userId').lean();
          const others = members.filter((m) => String(m.userId) !== String(user.id));
          await pushToUsers(others.map((m) => m.userId), {
            title: group.name,
            body: `${actorName} completed ${PRAYER_LABELS[prayer]}`,
            data: { type: 'prayer_completed', groupId: group.groupId, prayer },
          });
          if (dayCompleted) {
            await pushToUsers(members.map((m) => m.userId), {
              title: `${group.name} — day complete!`,
              body: `Everyone completed all five prayers. Streak is now ${group.currentStreak} — Mubarak!`,
              data: { type: 'group_day_completed', groupId: group.groupId },
            });
          }
        } catch (e) {
          console.warn('[streak] push fan-out failed:', e.message);
        }
      })();

      return {
        groupId: group.groupId,
        name: group.name,
        dateKey: gKey,
        currentStreak: group.currentStreak,
      };
    };

    const groupsTouched = await Promise.all(groups.map(tickGroup));

    res.json({
      success: true,
      data: {
        prayer,
        completed,
        solo: soloPayload(solo, soloRow),
        groups: groupsTouched,
      },
    });
  } catch (error) {
    next(error);
  }
};

// ─────────────────────────────────────────────────────────────────────────
// SOLO
// ─────────────────────────────────────────────────────────────────────────

export const getSolo = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    // Grace-aware: before Fajr the "open" day is still yesterday.
    const today = activePrayerDayKey(user.timezone);
    const row = await SoloDailyProgress.findOne({ userId: user.id, dateKey: today }).lean();
    if (!row) {
      const solo = await SoloStreak.findOne({ userId: user.id }).lean();
      if (!solo) return res.json({ success: true, data: { started: false, today: { completedCount: 0, isDayComplete: false } } });
      const fresh = await rollForwardSolo(await SoloStreak.findById(solo._id), user.id, user.timezone);
      return res.json({ success: true, data: soloPayload(fresh, null) });
    }
    const solo = await rollForwardSolo(await SoloStreak.findOne({ userId: user.id }), user.id, user.timezone);
    res.json({ success: true, data: soloPayload(solo, row) });
  } catch (error) {
    next(error);
  }
};

export const startSolo = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const solo = await rollForwardSolo(await SoloStreak.findOne({ userId: user.id }), user.id, user.timezone);
    res.status(201).json({ success: true, data: soloPayload(solo, null) });
  } catch (error) {
    next(error);
  }
};

export const getSoloHistory = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const now = new Date();
    const year = Number(req.query?.year) || now.getUTCFullYear();
    const month = Number(req.query?.month) || now.getUTCMonth() + 1;
    const todayKey = activePrayerDayKey(user.timezone);
    const rows = await SoloDailyProgress.find({
      userId: user.id,
      dateKey: { $regex: `^${year}-${String(month).padStart(2, '0')}` },
    }).select('dateKey isDayComplete completedCount').lean();
    const days = new Set(rows.filter((r) => r.isDayComplete).map((r) => r.dateKey));
    const byDate = Object.fromEntries(rows.map((r) => [r.dateKey, r]));
    const solo = await SoloStreak.findOne({ userId: user.id }).lean();
    const firstRequired = solo?.currentStreakStartDate || null;
    const calendar = buildMonthHistory(days, year, month, firstRequired, todayKey)
      .map((d) => ({ ...d, completedCount: byDate[d.dateKey]?.completedCount || 0 }));
    const fresh = await rollForwardSolo(await SoloStreak.findOne({ userId: user.id }), user.id, user.timezone);
    res.json({
      success: true,
      data: {
        year, month, calendar,
        currentStreak: fresh.currentStreak,
        bestStreak: fresh.bestStreak,
      },
    });
  } catch (error) {
    next(error);
  }
};

// ─────────────────────────────────────────────────────────────────────────
// GROUPS — membership helpers
// ─────────────────────────────────────────────────────────────────────────

const memberOf = async (groupId, userId) =>
  GroupMember.findOne({ groupId, userId: new mongoose.Types.ObjectId(userId) });

const requireMembership = async (res, groupId, userId, { activeOnly = true } = {}) => {
  const group = await Group.findOne({ groupId });
  if (!group) {
    fail(res, 404, 'GROUP_NOT_FOUND', 'Group no longer exists');
    return null;
  }
  const member = await memberOf(groupId, userId);
  if (!member || (activeOnly && member.status !== 'active')) {
    fail(res, 403, 'NOT_MEMBER', 'You are not an active member of this group');
    return null;
  }
  return { group, member };
};

// ── Capacity: atomic slot reservation ─────────────────────────────────────
// `memberCount` IS the reservation counter. Admission is a single atomic
// findOneAndUpdate ($inc guarded by the limit), so two concurrent joins can
// never both take the last slot — the old countDocuments() -> check ->
// insert sequence could overshoot maxMembers (no replica set here, so no
// transactions to lean on).
//
// Drift only ever makes the group look FULLER (fail-closed): a crash between
// reserve and insert leaves a phantom slot, never an extra member.
// scripts/repairGhostMembers.js reconciles it back to the real count.
const reserveGroupSlot = async (groupId) =>
  Group.findOneAndUpdate(
    {
      groupId,
      status: 'active',
      $expr: { $lt: ['$memberCount', GROUP_MEMBER_LIMIT_DEFAULT] },
    },
    { $inc: { memberCount: 1 } },
    { new: true },
  );

const releaseGroupSlot = async (groupId) => {
  try {
    await Group.updateOne(
      { groupId, $expr: { $gt: ['$memberCount', 0] } },
      { $inc: { memberCount: -1 } },
    );
  } catch (e) {
    // Best effort: a leaked slot only makes the group stricter, never wider.
    console.warn('[streak] slot release failed:', e.message);
  }
};

const addMemberToGroup = async (group, user, role = 'member') => {
  const effectiveFrom = effectiveFromForJoin(new Date(), group.timezone);
  const existing = await memberOf(group.groupId, user.id);
  if (existing) {
    existing.status = 'active';
    existing.role = role;
    existing.joinedAt = new Date();
    // Required for group-day completion from the NEXT day — the joiner's
    // own progress still counts and shows from today.
    existing.effectiveFromDate = effectiveFrom;
    existing.displayName = user.displayName;
    existing.leftAt = null;
    await existing.save();
  } else {
    await GroupMember.create({
      groupId: group.groupId, userId: new mongoose.Types.ObjectId(user.id),
      displayName: user.displayName, role, status: 'active', effectiveFromDate: effectiveFrom,
    });
  }
  // NOTE: memberCount is NOT recounted here. Callers reserve a slot first
  // (atomic $inc) — a blind recount would overwrite a concurrent reservation
  // and re-open the maxMembers race.
  await GroupActivity.create({
    groupId: group.groupId, userId: new mongoose.Types.ObjectId(user.id),
    displayName: user.displayName, type: 'member_joined',
  });
};

const generateInviteCode = async () => {
  for (let i = 0; i < 8; i++) {
    const code = randomCode(6);
    const clash = await Group.exists({ inviteCode: code });
    if (!clash) return code;
  }
  return randomCode(10);
};

// ─────────────────────────────────────────────────────────────────────────
// GROUPS — CRUD / listing
// ─────────────────────────────────────────────────────────────────────────

export const getMyGroups = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const memberships = await GroupMember.find({ userId: user.id, status: 'active' })
      .sort({ createdAt: -1 }).lean();
    if (memberships.length === 0) return res.json({ success: true, data: { groups: [] } });
    const groups = await Group.find({ groupId: { $in: memberships.map((m) => m.groupId) } });
    const membershipByGroup = new Map(memberships.map((m) => [m.groupId, m]));
    // Per-group reads run concurrently — a serial await per group made this
    // endpoint O(groups × 6 roundtrips) deep.
    const out = await Promise.all(groups.map(async (g) => {
      const fresh = await rollForwardGroup(g);
      const gKey = activePrayerDayKey(g.timezone);
      const membership = membershipByGroup.get(g.groupId);
      const eligible = isMemberEligibleOn(membership, gKey);
      const [myRow, allRequired, doneToday, summaryToday] = await Promise.all([
        GroupDailyProgress.findOne({
          groupId: g.groupId, userId: new mongoose.Types.ObjectId(user.id), dateKey: gKey,
        }).lean(),
        GroupMember.find({
          groupId: g.groupId, status: 'active', effectiveFromDate: { $lte: gKey },
        }).select('userId effectiveFromDate').lean(),
        GroupDailyProgress.countDocuments({
          groupId: g.groupId, dateKey: gKey, eligible: true, isDayComplete: true,
        }),
        GroupDailySummary.findOne({ groupId: g.groupId, dateKey: gKey }).select('isGroupDayComplete shielded').lean(),
      ]);
      // Ghost exclusion (Fix 2a): required count excludes 3-day ghosts.
      const requiredToday = (await ghostFreeMembers(g.groupId, gKey, allRequired)).length;
      return {
        groupId: g.groupId,
        name: g.name,
        status: g.status,
        visibility: g.visibility,
        timezone: g.timezone,
        memberCount: g.memberCount,
        role: membership.role,
        currentStreak: fresh.currentStreak,
        bestStreak: fresh.bestStreak,
        myToday: {
          completedCount: myRow?.completedCount || 0,
          isDayComplete: !!myRow?.isDayComplete,
          eligible,
          required: eligible, // false today for brand-new joiners (counting but not blocking)
        },
        today: {
          required: requiredToday,
          completed: doneToday,
          isGroupDayComplete: !!summaryToday?.isGroupDayComplete,
          shielded: !!summaryToday?.shielded,
        },
        shieldAvailable: fresh.shieldUsedWeekKey !== weekKeyOf(gKey),
        isOwner: String(g.ownerId) === user.id,
      };
    }));
    res.json({ success: true, data: { groups: out } });
  } catch (error) {
    next(error);
  }
};

export const createGroup = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const name = String(req.body?.name || '').trim().slice(0, GROUP_NAME_MAX);
    const visibility = req.body?.visibility === 'public' ? 'public' : 'invite';
    if (name.length < 2) {
      return fail(res, 400, 'VALIDATION', 'Group name must be at least 2 characters');
    }
    const inviteCode = await generateInviteCode();
    const group = await Group.create({
      groupId: newGroupId(),
      name,
      ownerId: new mongoose.Types.ObjectId(user.id),
      inviteCode,
      visibility,
      timezone: user.timezone,
      memberCount: 1,
    });
    await addMemberToGroup(group, user, 'owner');
    await GroupActivity.create({
      groupId: group.groupId, userId: new mongoose.Types.ObjectId(user.id),
      displayName: user.displayName, type: 'group_created',
    });
    res.status(201).json({
      success: true,
      data: {
        groupId: group.groupId,
        name: group.name,
        status: group.status,
        visibility: group.visibility,
        timezone: group.timezone,
        memberCount: group.memberCount,
        inviteCode: group.inviteCode,
        currentStreak: group.currentStreak || 0,
        bestStreak: group.bestStreak || 0,
        currentStreakStartDate: group.currentStreakStartDate || null,
        isOwner: true,
        myRole: 'owner',
        dateKey: activePrayerDayKey(group.timezone),
      },
    });
  } catch (error) {
    next(error);
  }
};

export const getGroupDashboard = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const { groupId } = req.params;
    const ctx = await requireMembership(res, groupId, user.id, { activeOnly: false });
    if (!ctx) return;
    const { group, member } = ctx;
    const gKey = activePrayerDayKey(group.timezone);
    // All five reads are independent — run them in ONE parallel round
    // instead of sequentially (each Atlas roundtrip costs ~100ms+, which
    // made opening a group feel like a full reload).
    const [fresh, members, rows, summary, activity] = await Promise.all([
      rollForwardGroup(group),
      GroupMember.find({ groupId, status: 'active' })
        .select('userId displayName role effectiveFromDate status').lean(),
      GroupDailyProgress.find({ groupId, dateKey: gKey }).lean(),
      GroupDailySummary.findOne({ groupId, dateKey: gKey }).lean(),
      // Same feed filter as getGroupActivity — per-prayer rows are retired.
      GroupActivity.find({ groupId, type: { $ne: 'prayer_completed' } })
        .sort({ createdAt: -1 }).limit(ACTIVITY_PAGE_SIZE).lean(),
    ]);
    const rowByUser = new Map(rows.map((r) => [String(r.userId), r]));
    const eligibleMembers = members.filter((m) => isMemberEligibleOn(m, gKey));
    // Ghost exclusion (Fix 2a): members with 0 activity for 3+ days are
    // excluded from today's requirement (and flagged in the payload).
    const activeRequired = await ghostFreeMembers(groupId, gKey, eligibleMembers);
    const activeIds = new Set(activeRequired.map((m) => String(m.userId)));
    const memberProgress = members
      .map((m) => {
        const row = rowByUser.get(String(m.userId));
        const isEligible = isMemberEligibleOn(m, gKey);
        const excluded = isEligible && !activeIds.has(String(m.userId));
        return {
          userId: String(m.userId),
          displayName: m.displayName,
          role: m.role,
          // `eligible`/`required`: member is part of TODAY's group-day
          // requirement. New joiners count/display from day one but become
          // required only from the next day, so a late join never blocks
          // an existing streak day. Ghosts are flagged, not hidden.
          eligible: isEligible,
          required: isEligible && !excluded,
          excludedInactive: excluded,
          completedCount: row?.completedCount || 0,
          isDayComplete: !!row?.isDayComplete,
          // Per-prayer flags for the Prayer Circle bottom sheet.
          fajr: !!row?.fajr,
          dhuhr: !!row?.dhuhr,
          asr: !!row?.asr,
          maghrib: !!row?.maghrib,
          isha: !!row?.isha,
          isMe: String(m.userId) === user.id,
        };
      })
      .sort((a, b) => (a.isDayComplete === b.isDayComplete ? b.completedCount - a.completedCount : (a.isDayComplete ? -1 : 1)));

    const required = activeRequired.length;
    const done = memberProgress.filter((m) => m.eligible && m.required && m.isDayComplete).length;

    res.json({
      success: true,
      data: {
        group: {
          groupId: fresh.groupId,
          name: fresh.name,
          status: fresh.status,
          visibility: fresh.visibility,
          timezone: fresh.timezone,
          memberCount: fresh.memberCount,
          inviteCode: member.status === 'active' || String(fresh.ownerId) === user.id ? fresh.inviteCode : null,
          currentStreak: fresh.currentStreak,
          bestStreak: fresh.bestStreak,
          currentStreakStartDate: fresh.currentStreakStartDate,
          isOwner: String(fresh.ownerId) === user.id,
          myRole: member.role,
          dateKey: gKey,
        },
        members: memberProgress,
        today: {
          required,
          completed: done,
          isGroupDayComplete: !!summary?.isGroupDayComplete,
          shielded: !!summary?.shielded,
        },
        shieldAvailable: fresh.shieldUsedWeekKey !== weekKeyOf(gKey),
        activity: activity.map(activityDto),
      },
    });
  } catch (error) {
    next(error);
  }
};

const activityDto = (a) => ({
  id: a._id,
  groupId: a.groupId,
  userId: String(a.userId),
  displayName: a.displayName,
  type: a.type,
  prayer: a.prayer || null,
  dateKey: a.dateKey || null,
  createdAt: a.createdAt,
});

export const getGroupActivity = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const { groupId } = req.params;
    const ctx = await requireMembership(res, groupId, user.id, { activeOnly: false });
    if (!ctx) return;
    const limit = Math.min(Number(req.query?.limit) || ACTIVITY_PAGE_SIZE, 50);
    const before = req.query?.before ? new Date(req.query.before) : null;
    // Feed is EVENTS only — per-prayer entries were retired; old rows stay
    // in the DB but are filtered out of every feed.
    const q = { groupId, type: { $ne: 'prayer_completed' }, ...(before ? { createdAt: { $lt: before } } : {}) };
    const items = await GroupActivity.find(q).sort({ createdAt: -1 }).limit(limit + 1).lean();
    const hasMore = items.length > limit;
    res.json({
      success: true,
      data: {
        items: items.slice(0, limit).map(activityDto),
        hasMore,
        nextCursor: hasMore ? items[limit - 1].createdAt : null,
      },
    });
  } catch (error) {
    next(error);
  }
};

export const getGroupHistory = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const { groupId } = req.params;
    const ctx = await requireMembership(res, groupId, user.id, { activeOnly: false });
    if (!ctx) return;
    const { group } = ctx;
    const fresh = await rollForwardGroup(group);
    const now = new Date();
    const year = Number(req.query?.year) || now.getUTCFullYear();
    const month = Number(req.query?.month) || now.getUTCMonth() + 1;
    const todayKey = activePrayerDayKey(group.timezone);
    const summaries = await GroupDailySummary.find({
      groupId,
      dateKey: { $regex: `^${year}-${String(month).padStart(2, '0')}` },
    }).select('dateKey isGroupDayComplete').lean();
    const days = new Set(summaries.filter((s) => s.isGroupDayComplete).map((s) => s.dateKey));
    const firstMember = await GroupMember.findOne({ groupId }).sort({ joinedAt: 1 }).select('effectiveFromDate').lean();
    const firstRequired = firstMember?.effectiveFromDate || null;
    const calendar = buildMonthHistory(days, year, month, firstRequired, todayKey);
    // previous streak period (run before the current one)
    res.json({
      success: true,
      data: {
        year, month, calendar,
        currentStreak: fresh.currentStreak,
        bestStreak: fresh.bestStreak,
        currentStreakStartDate: fresh.currentStreakStartDate,
      },
    });
  } catch (error) {
    next(error);
  }
};

// ─────────────────────────────────────────────────────────────────────────
// MEMBER DETAIL — tap a member's name in the dashboard to see their
// today status, all-time totals and streaks (score = total prayers).
// ─────────────────────────────────────────────────────────────────────────

export const getMemberDetail = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const { groupId, userId } = req.params;
    const ctx = await requireMembership(res, groupId, user.id, { activeOnly: false });
    if (!ctx) return;
    const { group } = ctx;
    const target = await memberOf(groupId, userId);
    if (!target || target.status !== 'active') {
      return fail(res, 404, 'NOT_MEMBER', 'That user is not an active member');
    }
    const gKey = activePrayerDayKey(group.timezone);
    const rows = await GroupDailyProgress.find({
      groupId, userId: new mongoose.Types.ObjectId(userId),
    }).select('dateKey fajr dhuhr asr maghrib isha completedCount isDayComplete').lean();
    const totalPrayers = rows.reduce((s, r) => s + (r.completedCount || 0), 0);
    const completeDays = new Set(rows.filter((r) => r.isDayComplete).map((r) => r.dateKey));
    const todayRow = rows.find((r) => r.dateKey === gKey) || null;
    const { run, startDate } = currentRunFromDays(completeDays, gKey);
    const best = Math.max(longestRunFromDays(completeDays), run);
    res.json({
      success: true,
      data: {
        member: {
          userId: String(target.userId),
          displayName: target.displayName,
          role: target.role,
          joinedAt: target.joinedAt,
          requiredToday: isMemberEligibleOn(target, gKey),
          isMe: String(target.userId) === user.id,
        },
        today: {
          dateKey: gKey,
          fajr: !!todayRow?.fajr,
          dhuhr: !!todayRow?.dhuhr,
          asr: !!todayRow?.asr,
          maghrib: !!todayRow?.maghrib,
          isha: !!todayRow?.isha,
          completedCount: todayRow?.completedCount || 0,
          isDayComplete: !!todayRow?.isDayComplete,
        },
        totals: {
          score: totalPrayers,
          totalPrayers,
          completeDays: completeDays.size,
          currentStreak: run,
          bestStreak: best,
          currentStreakStartDate: startDate,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

// ─────────────────────────────────────────────────────────────────────────
// INVITE / JOIN / DISCOVER
// ─────────────────────────────────────────────────────────────────────────

export const getInvitePreview = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const code = String(req.params?.code || '').trim().toUpperCase();
    const group = await Group.findOne({ inviteCode: code });
    if (!group || group.status !== 'active') {
      return fail(res, 404, 'INVALID_INVITE', 'This invite is invalid or the group has ended');
    }
    const fresh = await rollForwardGroup(group);
    const member = await memberOf(group.groupId, user.id);
    const request = await JoinRequest.findOne({ groupId: group.groupId, userId: new mongoose.Types.ObjectId(user.id) });
    const owner = await User.findById(group.ownerId).select('displayName').lean();
    res.json({
      success: true,
      data: {
        group: {
          groupId: fresh.groupId,
          name: fresh.name,
          currentStreak: fresh.currentStreak,
          memberCount: fresh.memberCount,
          maxMembers: GROUP_MEMBER_LIMIT_DEFAULT,
          visibility: fresh.visibility,
          timezone: fresh.timezone,
          ownerName: owner?.displayName || 'Someone',
        },
        inviteCode: group.inviteCode,
        viewerState: member?.status === 'active'
          ? 'member'
          : request?.status === 'pending'
            ? 'pending'
            : request?.status === 'declined'
              ? 'declined'
              : 'none',
      },
    });
  } catch (error) {
    next(error);
  }
};

export const joinByInviteCode = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const code = String(req.params?.code || '').trim().toUpperCase();
    const group = await Group.findOne({ inviteCode: code });
    if (!group || group.status !== 'active') {
      return fail(res, 404, 'INVALID_INVITE', 'This invite is invalid or the group has ended');
    }
    const existing = await memberOf(group.groupId, user.id);
    if (existing?.status === 'active') {
      return res.json({
        success: true,
        data: { alreadyMember: true, groupId: group.groupId, name: group.name, message: 'You are already a member of this group' },
      });
    }
    // Atomic capacity check + reservation — two parallel joins with the same
    // invite code can no longer both slip past the last open slot.
    const reserved = await reserveGroupSlot(group.groupId);
    if (!reserved) {
      return fail(res, 400, 'GROUP_FULL', 'This group has reached its member limit');
    }
    try {
      await addMemberToGroup(group, user);
    } catch (e) {
      await releaseGroupSlot(group.groupId);
      throw e;
    }
    group.memberCount = reserved.memberCount;
    // Cancel any pending request — the user is in.
    await JoinRequest.updateOne(
      { groupId: group.groupId, userId: new mongoose.Types.ObjectId(user.id), status: 'pending' },
      { $set: { status: 'cancelled' } },
    );
    // Fire-and-forget: let owner/admins welcome the new member.
    (async () => {
      try {
        const admins = await GroupMember.find({
          groupId: group.groupId, role: { $in: ['owner', 'admin'] }, status: 'active',
        }).select('userId').lean();
        const others = admins.filter((a) => String(a.userId) !== String(user.id));
        await pushToUsers(others.map((a) => a.userId), {
          title: group.name,
          body: `${user.displayName || 'Someone'} joined via invite code`,
          data: { type: 'member_joined', groupId: group.groupId },
        });
      } catch (e) {
        console.warn('[streak] member-joined push failed:', e.message);
      }
    })();
    res.json({
      success: true,
      data: { alreadyMember: false, groupId: group.groupId, name: group.name, message: 'Joined! Your prayers count from today — you join the group day requirement from tomorrow.' },
    });
  } catch (error) {
    next(error);
  }
};

export const discoverGroups = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const q = String(req.query?.q || '').trim();
    const page = Math.max(0, Number(req.query?.page) || 0);
    if (q.length < 2) return res.json({ success: true, data: { items: [], page, hasMore: false } });
    const search = q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const [items, total] = await Promise.all([
      Group.find({ status: 'active', visibility: 'public', name: { $regex: search, $options: 'i' } })
        .sort({ memberCount: -1 })
        .skip(page * DISCOVER_PAGE_SIZE)
        .limit(DISCOVER_PAGE_SIZE + 1)
        .select('groupId name ownerId memberCount currentStreak bestStreak timezone')
        .lean(),
      Group.countDocuments({ status: 'active', visibility: 'public', name: { $regex: search, $options: 'i' } }),
    ]);
    const hasMore = items.length > DISCOVER_PAGE_SIZE;
    const mine = await GroupMember.find({ userId: user.id, status: 'active' }).select('groupId').lean();
    const myGroupIds = new Set(mine.map((m) => m.groupId));
    const ownerIds = [...new Set(items.map((g) => g.ownerId))];
    const owners = ownerIds.length
      ? await User.find({ _id: { $in: ownerIds } }).select('displayName').lean()
      : [];
    const ownerName = new Map(owners.map((o) => [String(o._id), o.displayName]));
    res.json({
      success: true,
      data: {
        page,
        hasMore,
        total,
        items: items.slice(0, DISCOVER_PAGE_SIZE).map((g) => ({
          groupId: g.groupId,
          name: g.name,
          memberCount: g.memberCount,
          currentStreak: g.currentStreak,
          ownerName: ownerName.get(String(g.ownerId)) || 'Someone',
          isMember: myGroupIds.has(g.groupId),
        })),
      },
    });
  } catch (error) {
    next(error);
  }
};

// ─────────────────────────────────────────────────────────────────────────
// JOIN REQUESTS (search flow: request → owner approves/declines)
// ─────────────────────────────────────────────────────────────────────────

export const requestToJoin = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const { groupId } = req.params;
    const group = await Group.findOne({ groupId, status: 'active' });
    if (!group) return fail(res, 404, 'GROUP_NOT_FOUND', 'Group no longer exists');
    if (group.visibility !== 'public') {
      return fail(res, 403, 'INVITE_ONLY', 'This group is invite-only — ask a member for the invite code');
    }
    const member = await memberOf(groupId, user.id);
    if (member?.status === 'active') {
      return res.json({ success: true, data: { state: 'member', groupId } });
    }
    const activeCount = await GroupMember.countDocuments({ groupId, status: 'active' });
    if (activeCount >= GROUP_MEMBER_LIMIT_DEFAULT) {
      return fail(res, 400, 'GROUP_FULL', 'This group has reached its member limit');
    }
    // One row per (group,user): pending → return as-is; declined/cancelled → re-request.
    let request = await JoinRequest.findOne({ groupId, userId: new mongoose.Types.ObjectId(user.id) });
    if (!request) {
      request = await JoinRequest.create({
        groupId, userId: new mongoose.Types.ObjectId(user.id), displayName: user.displayName, status: 'pending',
      });
    } else if (request.status !== 'pending') {
      request.status = 'pending';
      request.decidedAt = null;
      request.displayName = user.displayName;
      await request.save();
    }
    // Fire-and-forget: owner/admins need to know so they can approve/decline.
    (async () => {
      try {
        const admins = await GroupMember.find({
          groupId, role: { $in: ['owner', 'admin'] }, status: 'active',
        }).select('userId').lean();
        await pushToUsers(admins.map((a) => a.userId), {
          title: group.name,
          body: `${user.displayName || 'Someone'} wants to join the group`,
          data: { type: 'join_request', groupId },
        });
      } catch (e) {
        console.warn('[streak] join-request push failed:', e.message);
      }
    })();
    res.status(201).json({ success: true, data: { state: 'pending', requestId: request._id } });
  } catch (error) {
    next(error);
  }
};

export const getMyRequests = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const items = await JoinRequest.find({ userId: new mongoose.Types.ObjectId(user.id), status: 'pending' })
      .sort({ createdAt: -1 }).lean();
    const names = items.length
      ? await Group.find({ groupId: { $in: items.map((i) => i.groupId) } }).select('groupId name').lean()
      : [];
    const nameMap = new Map(names.map((n) => [n.groupId, n.name]));
    res.json({
      success: true,
      data: {
        items: items.map((i) => ({ id: i._id, groupId: i.groupId, groupName: nameMap.get(i.groupId) || 'Group', status: i.status, createdAt: i.createdAt })),
      },
    });
  } catch (error) {
    next(error);
  }
};

export const getGroupRequests = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const { groupId } = req.params;
    const ctx = await requireMembership(res, groupId, user.id);
    if (!ctx) return;
    if (!['owner', 'admin'].includes(ctx.member.role)) {
      return fail(res, 403, 'ADMIN_ONLY', 'Only the owner or an admin can view join requests');
    }
    const items = await JoinRequest.find({ groupId, status: 'pending' }).sort({ createdAt: 1 }).lean();
    res.json({
      success: true,
      data: {
        items: items.map((i) => ({ id: i._id, userId: String(i.userId), displayName: i.displayName, createdAt: i.createdAt })),
      },
    });
  } catch (error) {
    next(error);
  }
};

const decideRequest = async (req, res, approve) => {
  const user = await resolveUser(req);
  const { requestId } = req.params;
  const request = await JoinRequest.findById(requestId);
  if (!request || request.status !== 'pending') {
    return fail(res, 404, 'REQUEST_NOT_FOUND', 'No pending request found');
  }
  const group = await Group.findOne({ groupId: request.groupId });
  if (!group || group.status !== 'active') {
    return fail(res, 404, 'GROUP_NOT_FOUND', 'Group no longer exists');
  }
  const actor = await memberOf(request.groupId, user.id);
  if (!actor || actor.status !== 'active' || !['owner', 'admin'].includes(actor.role)) {
    return fail(res, 403, 'ADMIN_ONLY', 'Only the owner or an admin can decide requests');
  }
  if (String(request.userId) === user.id) {
    return fail(res, 403, 'FORBIDDEN', 'You cannot decide your own request');
  }
  if (approve) {
    // Reserve before admitting (same atomic guard as direct invite joins).
    const reserved = await reserveGroupSlot(request.groupId);
    if (!reserved) {
      return fail(res, 400, 'GROUP_FULL', 'This group has reached its member limit');
    }
    try {
      const target = await User.findById(request.userId).select('displayName').lean();
      await addMemberToGroup(group, { id: String(request.userId), displayName: target?.displayName || request.displayName });
    } catch (e) {
      await releaseGroupSlot(request.groupId);
      throw e;
    }
    group.memberCount = reserved.memberCount;
  }
  request.status = approve ? 'approved' : 'declined';
  request.decidedAt = new Date();
  await request.save();
  // Fire-and-forget: the requester is waiting on this decision.
  (async () => {
    try {
      await pushToUsers([request.userId], {
        title: group.name,
        body: approve
          ? 'Your join request was approved — welcome!'
          : 'Your join request was declined',
        data: { type: 'join_decided', groupId: group.groupId, approved: approve },
      });
    } catch (e) {
      console.warn('[streak] join-decided push failed:', e.message);
    }
  })();
  res.json({ success: true, data: { status: request.status } });
};

export const approveRequest = async (req, res, next) => {
  try { await decideRequest(req, res, true); } catch (e) { next(e); }
};
export const declineRequest = async (req, res, next) => {
  try { await decideRequest(req, res, false); } catch (e) { next(e); }
};

// ─────────────────────────────────────────────────────────────────────────
// GROUP MANAGEMENT
// ─────────────────────────────────────────────────────────────────────────

export const leaveGroup = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const { groupId } = req.params;
    const ctx = await requireMembership(res, groupId, user.id);
    if (!ctx) return;
    const { group, member } = ctx;
    if (member.role === 'owner') {
      return fail(res, 400, 'OWNER_MUST_TRANSFER', 'Transfer ownership or archive the group before leaving');
    }
    const wasActive = member.status === 'active';
    member.status = 'left';
    member.leftAt = new Date();
    await member.save();
    // Exactly one atomic decrement per active -> inactive transition. A
    // countDocuments() recount here would overwrite a concurrent join's
    // reservation and silently re-open the maxMembers race.
    if (wasActive) await releaseGroupSlot(groupId);
    await GroupActivity.create({
      groupId, userId: new mongoose.Types.ObjectId(user.id),
      displayName: user.displayName, type: 'member_left',
    });
    res.json({ success: true, data: { message: 'You left the group. History is preserved.' } });
  } catch (error) {
    next(error);
  }
};

export const removeMember = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const { groupId, userId } = req.params;
    const ctx = await requireMembership(res, groupId, user.id);
    if (!ctx) return;
    const { group, member } = ctx;
    if (!['owner', 'admin'].includes(member.role)) {
      return fail(res, 403, 'ADMIN_ONLY', 'Only the owner or an admin can remove members');
    }
    const target = await memberOf(groupId, userId);
    if (!target || target.status !== 'active') {
      return fail(res, 404, 'NOT_MEMBER', 'That user is not an active member');
    }
    if (target.role === 'owner') {
      return fail(res, 403, 'FORBIDDEN', 'The owner cannot be removed');
    }
    if (String(userId) === user.id) {
      return fail(res, 400, 'USE_LEAVE', 'Use leave group instead');
    }
    target.status = 'removed';
    target.leftAt = new Date();
    await target.save();
    // target.status was checked 'active' above — one decrement, no recount.
    await releaseGroupSlot(groupId);
    await GroupActivity.create({
      groupId, userId: new mongoose.Types.ObjectId(userId),
      displayName: target.displayName, type: 'member_removed',
    });
    res.json({ success: true, data: { message: 'Member removed. History is preserved.' } });
  } catch (error) {
    next(error);
  }
};

export const renameGroup = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const { groupId } = req.params;
    const ctx = await requireMembership(res, groupId, user.id);
    if (!ctx) return;
    if (!['owner', 'admin'].includes(ctx.member.role)) {
      return fail(res, 403, 'ADMIN_ONLY', 'Only the owner or an admin can rename the group');
    }
    const name = String(req.body?.name || '').trim().slice(0, GROUP_NAME_MAX);
    if (name.length < 2) return fail(res, 400, 'VALIDATION', 'Group name must be at least 2 characters');
    ctx.group.name = name; // names are display-only — duplicates allowed
    await ctx.group.save();
    res.json({ success: true, data: { name } });
  } catch (error) {
    next(error);
  }
};

export const rotateInviteCode = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const { groupId } = req.params;
    const ctx = await requireMembership(res, groupId, user.id);
    if (!ctx) return;
    if (!['owner', 'admin'].includes(ctx.member.role)) {
      return fail(res, 403, 'ADMIN_ONLY', 'Only the owner or an admin can rotate the invite code');
    }
    ctx.group.inviteCode = await generateInviteCode();
    await ctx.group.save();
    res.json({ success: true, data: { inviteCode: ctx.group.inviteCode } });
  } catch (error) {
    next(error);
  }
};

export const transferOwnership = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const { groupId } = req.params;
    const targetUserId = String(req.body?.userId || '');
    const ctx = await requireMembership(res, groupId, user.id);
    if (!ctx) return;
    if (ctx.member.role !== 'owner') {
      return fail(res, 403, 'OWNER_ONLY', 'Only the owner can transfer ownership');
    }
    const target = await memberOf(groupId, targetUserId);
    if (!target || target.status !== 'active') {
      return fail(res, 404, 'NOT_MEMBER', 'That user is not an active member');
    }
    if (String(targetUserId) === user.id) {
      return fail(res, 400, 'VALIDATION', 'You already own this group');
    }
    ctx.member.role = 'admin';
    await ctx.member.save();
    target.role = 'owner';
    await target.save();
    ctx.group.ownerId = new mongoose.Types.ObjectId(targetUserId);
    await ctx.group.save();
    await GroupActivity.create({
      groupId, userId: new mongoose.Types.ObjectId(targetUserId),
      displayName: target.displayName, type: 'ownership_transferred',
    });
    res.json({ success: true, data: { message: 'Ownership transferred' } });
  } catch (error) {
    next(error);
  }
};

export const archiveGroup = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const { groupId } = req.params;
    const ctx = await requireMembership(res, groupId, user.id);
    if (!ctx) return;
    if (ctx.member.role !== 'owner') {
      return fail(res, 403, 'OWNER_ONLY', 'Only the owner can archive the group');
    }
    if (ctx.group.status === 'archived') {
      return res.json({ success: true, data: { message: 'Group already archived' } });
    }
    ctx.group.status = 'archived';
    ctx.group.archivedAt = new Date();
    await ctx.group.save();
    await GroupActivity.create({
      groupId, userId: new mongoose.Types.ObjectId(user.id),
      displayName: user.displayName, type: 'group_archived',
    });
    res.json({ success: true, data: { message: 'Group archived. Full history is preserved.' } });
  } catch (error) {
    next(error);
  }
};

// ─────────────────────────────────────────────────────────────────────────
// NOTIFICATIONS (in-app feed; FCM-ready — streak never depends on them)
// ─────────────────────────────────────────────────────────────────────────

export const getNotifications = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const me = await User.findById(user.id).select('notificationsSeenAt').lean();
    const seenAt = me?.notificationsSeenAt || new Date(0);
    const memberships = await GroupMember.find({ userId: user.id, status: 'active' }).select('groupId').lean();
    const groupIds = memberships.map((m) => m.groupId);
    if (groupIds.length === 0) return res.json({ success: true, data: { items: [], unread: 0 } });
    const groups = await Group.find({ groupId: { $in: groupIds } }).select('groupId name').lean();
    const nameMap = new Map(groups.map((g) => [g.groupId, g.name]));
    const items = await GroupActivity.find({
      groupId: { $in: groupIds },
      userId: { $ne: new mongoose.Types.ObjectId(user.id) }, // never your own actions
      type: { $in: ['group_day_completed', 'member_joined', 'member_left', 'member_removed'] },
    })
      .sort({ createdAt: -1 })
      .limit(30)
      .lean();
    const unread = await GroupActivity.countDocuments({
      groupId: { $in: groupIds },
      userId: { $ne: new mongoose.Types.ObjectId(user.id) },
      type: { $in: ['group_day_completed', 'member_joined', 'member_left', 'member_removed'] },
      createdAt: { $gt: seenAt },
    });
    res.json({
      success: true,
      data: {
        unread,
        items: items.map((a) => ({ ...activityDto(a), groupName: nameMap.get(a.groupId) || '' })),
      },
    });
  } catch (error) {
    next(error);
  }
};

export const markNotificationsSeen = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    await User.updateOne({ _id: user.id }, { $set: { notificationsSeenAt: new Date() } });
    res.json({ success: true, data: { seen: true } });
  } catch (error) {
    next(error);
  }
};

export const registerDevice = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const token = String(req.body?.token || '').trim();
    if (!token) return fail(res, 400, 'VALIDATION', 'Token is required');
    await PushToken.updateOne(
      { userId: new mongoose.Types.ObjectId(user.id), token },
      { $set: { platform: req.body?.platform || 'android' } },
      { upsert: true },
    );
    res.json({ success: true, data: { registered: true } });
  } catch (error) {
    next(error);
  }
};

// ─────────────────────────────────────────────────────────────────────────
// NUDGE — "tap a member → send a friendly reminder". Push-only; the streak
// never depends on it. Rate limits (in-memory, sufficient for a single
// node process — this backend is not horizontally scaled):
//   • once per (sender → target, prayer) per active day
//   • max 3 nudges per target per day (from anyone)
// ─────────────────────────────────────────────────────────────────────────

const nudgeState = new Map(); // key -> { count, lastAt }
const NUDGE_MAX_PER_TARGET_PER_DAY = 3;
const NUDGE_WINDOW_MS = 24 * 60 * 60 * 1000;

const nudgeRateKey = (targetId, dayKey) => `nudge:${targetId}:${dayKey}`;
const nudgePairKey = (senderId, targetId, prayer, dayKey) =>
  `nudgepair:${senderId}:${targetId}:${prayer || 'any'}:${dayKey}`;

// Drop stale entries opportunistically so the Map never grows unbounded.
const nudgePrune = () => {
  if (nudgeState.size < 5000) return;
  const cutoff = Date.now() - NUDGE_WINDOW_MS;
  for (const [k, v] of nudgeState) {
    if (v.lastAt < cutoff) nudgeState.delete(k);
  }
};

export const nudgeMember = async (req, res, next) => {
  try {
    const user = await resolveUser(req);
    const groupId = String(req.body?.groupId || '').trim();
    const targetUserId = String(req.body?.targetUserId || '').trim();
    const prayerName = prayerOf(req.body?.prayerName) || null;
    if (!groupId || !targetUserId) {
      return fail(res, 400, 'VALIDATION', 'groupId and targetUserId are required');
    }
    if (prayerName && !PRAYERS.includes(prayerName)) {
      return fail(res, 400, 'INVALID_PRAYER', 'Invalid prayer name');
    }
    if (targetUserId === user.id) {
      return fail(res, 400, 'VALIDATION', 'You cannot nudge yourself');
    }
    const ctx = await requireMembership(res, groupId, user.id);
    if (!ctx) return;
    const { group } = ctx;
    const target = await memberOf(groupId, targetUserId);
    if (!target || target.status !== 'active') {
      return fail(res, 404, 'NOT_MEMBER', 'That user is not an active member');
    }

    // Rate limiting keyed on the GROUP's active prayer day.
    nudgePrune();
    const dayKey = activePrayerDayKey(group.timezone);
    const pairKey = nudgePairKey(user.id, targetUserId, prayerName, dayKey);
    const rateKey = nudgeRateKey(targetUserId, dayKey);
    const nowMs = Date.now();
    const pair = nudgeState.get(pairKey);
    if (pair && nowMs - pair.lastAt < NUDGE_WINDOW_MS) {
      return fail(res, 429, 'NUDGE_DUPLICATE', 'You already sent this nudge — try a different prayer or tomorrow');
    }
    const rate = nudgeState.get(rateKey);
    if (rate && nowMs - rate.lastAt < NUDGE_WINDOW_MS && rate.count >= NUDGE_MAX_PER_TARGET_PER_DAY) {
      return fail(res, 429, 'NUDGE_LIMIT', 'This member has received enough nudges today');
    }
    nudgeState.set(pairKey, { count: 1, lastAt: nowMs });
    nudgeState.set(rateKey, {
      count: (rate && nowMs - rate.lastAt < NUDGE_WINDOW_MS ? rate.count : 0) + 1,
      lastAt: nowMs,
    });

    // Fire-and-forget push — never blocks/negates the nudge response.
    (async () => {
      try {
        const label = prayerName ? PRAYER_LABELS[prayerName] : 'today\u2019s prayers';
        await pushToUsers([targetUserId], {
          title: group.name,
          body: `${user.displayName || 'A member'} is reminding you to complete ${label}`,
          data: { type: 'nudge', groupId: group.groupId, prayer: prayerName || '' },
        });
      } catch (e) {
        console.warn('[streak] nudge push failed:', e.message);
      }
    })();

    res.json({
      success: true,
      data: {
        nudged: true,
        targetUserId,
        prayer: prayerName,
        remainingToday: Math.max(
          0,
          NUDGE_MAX_PER_TARGET_PER_DAY - (nudgeState.get(rateKey)?.count || 0),
        ),
      },
    });
  } catch (error) {
    next(error);
  }
};

// ─────────────────────────────────────────────────────────────────────────
// ONE-TIME ACCOUNT RECOVERY — a reinstall generates a fresh deviceId, which
// orphans the old account (and any groups it owns). These endpoints let the
// operator look the group up and mint a fresh token for its owner, who can
// then re-link their device via POST /api/auth/link-device.
//
// Guarded by STREAK_REPAIR_KEY from the environment. The key is NOT in
// source: without the env var both endpoints return 404 (disabled), so a
// leaked/historical copy of this file grants nothing. Remove the routes
// entirely once the recovery window is closed.
// ─────────────────────────────────────────────────────────────────────────

const repairKeyFromEnv = () => {
  const key = String(process.env.STREAK_REPAIR_KEY || '').trim();
  // Refuse a trivially guessable key — better disabled than wide open.
  return key.length >= 16 ? key : null;
};

// Constant-time compare so the header can't be brute-forced byte-by-byte.
// (node:crypto — the global WebCrypto `crypto` has no timingSafeEqual.)
const safeEqual = (a, b) => {
  const ab = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  if (ab.length !== bb.length) return false;
  return timingSafeEqual(ab, bb);
};

const repairAuthorized = (req) => {
  const key = repairKeyFromEnv();
  if (!key) return false;
  return safeEqual(String(req.headers['x-repair-key'] || ''), key);
};

const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

export const repairFindGroups = async (req, res, next) => {
  try {
    if (!repairAuthorized(req)) return fail(res, 404, 'NOT_FOUND', 'Not found');
    const q = String(req.query?.name || '').trim();
    if (q.length < 2) return fail(res, 400, 'VALIDATION', 'name query (min 2 chars) required');
    const groups = await Group.find({
      status: 'active',
      name: { $regex: escapeRegex(q), $options: 'i' },
    })
      .select('groupId name ownerId memberCount visibility createdAt')
      .lean();
    const ownerIds = [...new Set(groups.map((g) => String(g.ownerId)))];
    const owners = ownerIds.length
      ? await User.find({ _id: { $in: ownerIds } }).select('displayName createdAt').lean()
      : [];
    const omap = new Map(owners.map((o) => [String(o._id), o]));
    res.json({
      success: true,
      data: {
        items: groups.map((g) => ({
          groupId: g.groupId,
          name: g.name,
          memberCount: g.memberCount,
          visibility: g.visibility,
          createdAt: g.createdAt,
          owner: {
            id: String(g.ownerId),
            displayName: omap.get(String(g.ownerId))?.displayName || '?',
            createdAt: omap.get(String(g.ownerId))?.createdAt || null,
          },
        })),
      },
    });
  } catch (error) {
    next(error);
  }
};

export const repairMintOwnerToken = async (req, res, next) => {
  try {
    if (!repairAuthorized(req)) return fail(res, 404, 'NOT_FOUND', 'Not found');
    const groupId = String(req.body?.groupId || '').trim();
    if (!groupId) return fail(res, 400, 'VALIDATION', 'groupId required');
    const group = await Group.findOne({ groupId, status: 'active' });
    if (!group) return fail(res, 404, 'GROUP_NOT_FOUND', 'Group not found');
    const owner = await User.findById(group.ownerId);
    if (!owner) return fail(res, 404, 'OWNER_NOT_FOUND', 'Owner account no longer exists');
    const token = jwt.sign(
      { id: owner._id, displayName: owner.displayName, timezone: owner.timezone },
      getJwtSecret(),
      { expiresIn: '30d' },
    );
    res.json({
      success: true,
      data: {
        token,
        user: {
          id: String(owner._id),
          displayName: owner.displayName,
          createdAt: owner.createdAt,
        },
        group: { groupId: group.groupId, name: group.name, memberCount: group.memberCount },
        nextStep: 'Open sajda://restore?token=...&userId=...&name=... on the device, then it calls /api/auth/link-device',
      },
    });
  } catch (error) {
    next(error);
  }
};
