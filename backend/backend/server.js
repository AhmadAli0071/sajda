import express from 'express';
import dotenv from 'dotenv';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import './config/env.js';
import connectDB, { dbConnected, lastDbError } from './config/db.js';
import { fcmEnabled } from './services/fcm.js';
import errorHandler from './middleware/errorHandler.js';
import { authenticateToken } from './middleware/auth.js';

import prayerRoutes from './routes/prayerRoutes.js';
import qiblaRoutes from './routes/qiblaRoutes.js';
import eventRoutes from './routes/eventRoutes.js';
import duaRoutes from './routes/duaRoutes.js';
import wazifaRoutes from './routes/wazifaRoutes.js';
import hijriRoutes from './routes/hijriRoutes.js';
import authRoutes from './routes/auth.js';
import streakRoutes from './routes/streakRoutes.js';
import streakV2Routes, { nudgeRouter } from './routes/streakV2Routes.js';
import quranRoutes from './routes/quranRoutes.js';
import ayatRoutes from './routes/ayatRoutes.js';
import adhkarRoutes from './routes/adhkarRoutes.js';
import appConfigRoutes from './routes/appConfigRoutes.js';
import { autoSeedContent } from './services/autoSeed.js';

dotenv.config({ path: join(dirname(fileURLToPath(import.meta.url)), '..', '.env') });

const app = express();
const PORT = process.env.PORT || 5000;
const __dirname = dirname(fileURLToPath(import.meta.url));

// Railway sits behind a reverse proxy. Without this, req.ip is the
// proxy's internal IP for EVERY client, which collapses the rate limiter
// into one global bucket shared by all users ("Too many requests" for
// everyone after a few app opens).
app.set('trust proxy', 1);



const checkDBConnection = (req, res, next) => {
  if (!dbConnected) {
    return res.status(503).json({ message: 'Database unavailable. Please try again later.' });
  }
  next();
};

app.use(helmet({
  crossOriginResourcePolicy: false,
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'", "https:"],
      imgSrc: ["'self'", "data:", "https:", "blob:"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
      fontSrc: ["'self'", "https://fonts.gstatic.com"],
      connectSrc: ["'self'", "https://fonts.googleapis.com", "https://fonts.gstatic.com", "https:"],
      frameSrc: ["'self'", "https:"],
      workerSrc: ["'self'", "blob:"],
    },
  },
}));
app.use(compression());
// Request logging is a dev tool — at 20k users it burns CPU and memory for
// nothing. Only enabled when explicitly running in development.
if (process.env.NODE_ENV === 'development') app.use(morgan('dev'));
app.use(cors({
  origin: [
    'https://policy.sajda.online',
    'https://sajdapolicy.57.129.161.5.nip.io', // legacy during migration
    'https://policy-production-980a.up.railway.app', // legacy policy site during migration
    'https://sajda-privacy.onrender.com', // legacy policy site during migration
  ],
  credentials: true,
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Serve built frontend (static assets, if a frontend build is bundled)
const distPath = join(__dirname, '..', 'dist');
app.use(express.static(distPath));

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'Sajda API is running' });
});

// Connectivity diagnostic — returns DB state and the last connection error
// message (no credentials). Used to debug network-level DB issues.
app.get('/api/db-status', (req, res) => {
  res.json({
    dbConnected,
    lastError: lastDbError,
    nodeVersion: process.version,
    envUriPresent: !!process.env.MONGODB_URI,
    envUriHosts: process.env.MONGODB_URI
      ? (process.env.MONGODB_URI.match(/@([^/?]+)\//) || [])[1] || ''
      : '',
  });
});

// Push diagnostic — is FIREBASE_SERVICE_ACCOUNT loaded and does any device
// token exist? Used to debug missing group-join / streak notifications.
app.get('/api/fcm-status', (req, res) => {
  res.json({
    fcmEnabled: fcmEnabled(),
    serviceAccountPresent: !!process.env.FIREBASE_SERVICE_ACCOUNT,
  });
});

app.use('/api/prayers', checkDBConnection, prayerRoutes);
app.use('/api/qibla', checkDBConnection, qiblaRoutes);
app.use('/api/events', checkDBConnection, eventRoutes);
app.use('/api/duas', checkDBConnection, duaRoutes);
app.use('/api/wazifas', checkDBConnection, wazifaRoutes);
app.use('/api/hijri', checkDBConnection, hijriRoutes);
app.use('/api/auth', checkDBConnection, authRoutes);
app.use('/api/streak', authenticateToken, checkDBConnection, streakRoutes);
// v2 streak system (Solo + Friends & Family groups). The v1 router above
// has no route matching `v2/...`, so requests fall through to this mount.
// v1 stays mounted for older app versions until they are retired.
app.use('/api/streak/v2', authenticateToken, checkDBConnection, streakV2Routes);
// Spec-exact nudge alias: POST /api/group/v2/nudge (same handler as
// /api/streak/v2/groups/nudge) for the documented Group Prayer Circle path.
app.use('/api/group/v2', authenticateToken, checkDBConnection, nudgeRouter);
app.use('/api/quran', checkDBConnection, quranRoutes);
app.use('/api/ayat', checkDBConnection, ayatRoutes);
app.use('/api/adhkar', checkDBConnection, adhkarRoutes);
// Public app-config (force-update gate) — no auth, no DB dependency so it
// answers even during a DB outage (failing closed would lock users out).
app.use('/api/app-config', appConfigRoutes);

// Fallback: serve index.html for any non-API route (SPA)
app.get('*', (req, res) => {
  res.sendFile(join(distPath, 'index.html'));
});

app.use(errorHandler);

connectDB().then(() => {
  // Fire-and-forget: fills adhkar/ayat content on an empty database
  // without ever blocking startup.
  autoSeedContent();
  app.listen(PORT, () => {
    console.log(`Sajda server running on port ${PORT}`);
  });
}).catch((err) => {
  console.error('Failed to start server:', err.message);
  app.listen(PORT, () => {
    console.log(`Sajda server running on port ${PORT} (without database)`);
  });
});

export default app;


