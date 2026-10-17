import mongoose from 'mongoose';

// GROUP DAILY SUMMARY — one row per group per dateKey. The atomic
// `isGroupDayComplete` flip (conditional findOneAndUpdate) guarantees the
// day completes exactly ONCE even when the final members finish
// simultaneously. Streak is derived from these rows — never incremented.
const groupDailySummarySchema = new mongoose.Schema({
  groupId: { type: String, required: true, index: true },
  dateKey: { type: String, required: true, index: true },
  eligibleCount: { type: Number, default: 0, min: 0 },
  completedCount: { type: Number, default: 0, min: 0 },
  isGroupDayComplete: { type: Boolean, default: false },
  // Weekly group shield (Fix 2b): a missed-but-≥80% day is auto-completed.
  shielded: { type: Boolean, default: false },
  completedAt: { type: Date },
}, { timestamps: true });

groupDailySummarySchema.index({ groupId: 1, dateKey: 1 }, { unique: true });

export default mongoose.model('GroupDailySummary', groupDailySummarySchema);
