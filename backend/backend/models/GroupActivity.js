import mongoose from 'mongoose';

// GROUP ACTIVITY — focused streak activity feed. Natural-idempotent:
// prayer events are only inserted when a prayer flag actually flips.
const groupActivitySchema = new mongoose.Schema({
  groupId: { type: String, required: true, index: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  displayName: { type: String, required: true },
  type: {
    type: String,
    enum: [
      'group_created', 'prayer_completed', 'member_joined', 'member_left',
      'member_removed', 'group_day_completed', 'ownership_transferred', 'group_archived',
      'group_shield_used',
    ],
    required: true,
  },
  prayer: { type: String, enum: ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'] },
  dateKey: { type: String }, // for day-complete events (revertible)
  createdAt: { type: Date, default: Date.now, index: true },
});

groupActivitySchema.index({ groupId: 1, createdAt: -1 });
groupActivitySchema.index({ groupId: 1, type: 1, createdAt: -1 });

export default mongoose.model('GroupActivity', groupActivitySchema);
