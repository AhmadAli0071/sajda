import mongoose from 'mongoose';

// FRIENDS & FAMILY GROUP.
// - `name` is a display name only — duplicates are allowed.
// - `groupId` is the unique internal id (grp_xxxxxxxx).
// - `inviteCode` is globally unique and identifies exactly one group.
// - `timezone` defines the group day boundary (all members share it).
// - streak values are DERIVED from group_daily_summaries.
const groupSchema = new mongoose.Schema({
  groupId: { type: String, required: true, unique: true, index: true },
  name: { type: String, required: true, trim: true, maxlength: 60 },
  ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  inviteCode: { type: String, required: true, unique: true, index: true },
  visibility: { type: String, enum: ['public', 'invite'], default: 'invite' },
  status: { type: String, enum: ['active', 'archived'], default: 'active' },
  timezone: { type: String, default: 'Asia/Karachi' },
  memberCount: { type: Number, default: 1, min: 0 },
  currentStreak: { type: Number, default: 0, min: 0 },
  bestStreak: { type: Number, default: 0, min: 0 },
  currentStreakStartDate: { type: String },
  lastCompletedDay: { type: String },
  lastEvaluatedDay: { type: String },
  // Weekly group shield: Monday-start weekKey ('YYYY-MM-DD') the shield was
  // last consumed on. One shield per week — compare with weekKeyOf(dateKey).
  shieldUsedWeekKey: { type: String },
  archivedAt: { type: Date },
}, { timestamps: true });

groupSchema.index({ name: 'text' });
groupSchema.index({ visibility: 1, status: 1, memberCount: -1 });
groupSchema.index({ ownerId: 1, status: 1 });

export default mongoose.model('Group', groupSchema);
