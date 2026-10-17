import { Router } from 'express';

const router = Router();

// Public app-configuration endpoint — consulted once at app launch.
//
// Environment-driven (Remote-Config style): bump MIN_REQUIRED_VERSION to
// force every older client into the update gate. '0.0.0' (default) means
// "no minimum" so a missing/failed config NEVER blocks app usage.
//
//   MIN_REQUIRED_VERSION=2.1.0
//   LATEST_VERSION=2.1.0
//   RELEASE_NOTES="Faster Qibla compass and bug fixes"
//   APP_STORE_URL=https://apps.apple.com/app/idXXXXXXXX
router.get('/', (req, res) => {
  res.json({
    success: true,
    data: {
      min_required_version: process.env.MIN_REQUIRED_VERSION || '0.0.0',
      latest_version: process.env.LATEST_VERSION || '',
      release_notes: process.env.RELEASE_NOTES || '',
      play_store_url:
        process.env.PLAY_STORE_URL ||
        'https://play.google.com/store/apps/details?id=com.sajda.dataplus',
      app_store_url: process.env.APP_STORE_URL || '',
    },
  });
});

export default router;
