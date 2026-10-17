import { Router } from 'express';
import {
  getSolo,
  startSolo,
  getSoloHistory,
  completePrayer,
  getMyGroups,
  createGroup,
  discoverGroups,
  getGroupDashboard,
  getGroupActivity,
  getGroupHistory,
  getMemberDetail,
  leaveGroup,
  removeMember,
  renameGroup,
  rotateInviteCode,
  transferOwnership,
  archiveGroup,
  requestToJoin,
  getMyRequests,
  getGroupRequests,
  approveRequest,
  declineRequest,
  getInvitePreview,
  joinByInviteCode,
  getNotifications,
  markNotificationsSeen,
  registerDevice,
  nudgeMember,
  repairFindGroups,
  repairMintOwnerToken,
} from '../controllers/streakV2Controller.js';
import { writeLimiter } from '../middleware/rateLimiter.js';

const router = Router();

// Reads are unlimited — the app's normal flow is a handful of GETs per
// screen and rate limiting them only punishes shared-IP (CGNAT) users.
// Writes carry a generous per-USER limit (see rateLimiter.js).
const W = writeLimiter;

// ── Solo streak ──
router.get('/solo', getSolo);
router.post('/solo/start', W, startSolo);
router.post('/prayers/complete', W, completePrayer); // THE one canonical prayer tick
router.get('/solo/history', getSoloHistory);

// ── Groups: discovery & listing (static paths BEFORE :groupId) ──
router.get('/groups', getMyGroups);
router.post('/groups', W, createGroup);
router.get('/groups/discover', discoverGroups);
router.get('/requests/me', getMyRequests);

// ── Invite code / deep link ──
router.get('/invite/:code', getInvitePreview);
router.post('/invite/:code/join', W, joinByInviteCode);

// ── Join requests ──
router.post('/groups/:groupId/join-request', W, requestToJoin);
router.get('/groups/:groupId/requests', getGroupRequests);
router.post('/requests/:requestId/approve', W, approveRequest);
router.post('/requests/:requestId/decline', W, declineRequest);

// ── Group dashboard / activity / history / member detail ──
router.get('/groups/:groupId/dashboard', getGroupDashboard);
router.get('/groups/:groupId/activity', getGroupActivity);
router.get('/groups/:groupId/history', getGroupHistory);
router.get('/groups/:groupId/members/:userId', getMemberDetail);

// ── Group management ──
router.post('/groups/:groupId/leave', W, leaveGroup);
router.post('/groups/:groupId/rename', W, renameGroup);
router.post('/groups/:groupId/invite/rotate', W, rotateInviteCode);
router.post('/groups/:groupId/members/:userId/remove', W, removeMember);
router.post('/groups/:groupId/transfer', W, transferOwnership);
router.post('/groups/:groupId/archive', W, archiveGroup);

// ── Notifications (in-app feed; FCM-ready) & devices ──
router.get('/notifications', getNotifications);
router.post('/notifications/seen', W, markNotificationsSeen);
router.post('/devices', W, registerDevice);

// ── Nudge — also available at POST /api/group/v2/nudge (see nudgeRouter) ──
router.post('/groups/nudge', W, nudgeMember);

// ── ONE-TIME account recovery (remove after use) ──
router.get('/admin-repair/groups', repairFindGroups);
router.post('/admin-repair/mint', repairMintOwnerToken);

// Spec-exact alias: POST /api/group/v2/nudge — mounted separately in
// server.js so the documented path works alongside /api/streak/v2.
export const nudgeRouter = Router();
nudgeRouter.post('/nudge', W, nudgeMember);

export default router;
