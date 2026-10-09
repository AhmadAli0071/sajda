# Deployment Guide â€” Sajda App

> Ye guide Sep 20, 2026 ke Railway deployment se shuru hui thi.
> **Oct 9, 2026 se backend self-hosted OVH VPS pe hai** (neeche Section 0).

---

## 0. CURRENT: Backend on VPS (Oct 9, 2026 se)

| Cheez | Detail |
|---|---|
| **Backend** (`/backend`, Node.js) | **OVH VPS** (57.129.161.5) â€” PM2 + Nginx + Let's Encrypt |
| **Live URL** | `https://api.sajda.online/api` |
| **Health check** | `GET /api/health` â†’ `200` |
| **Folder** | `/home/ubuntu/S-Backup/sajda` |
| **Port** | `5001` (internal), nginx se proxy |
| **PM2 name** | `sajda-api` |
| **DB** | MongoDB Atlas (cloud â€” local MongoDB nahi) |
| **VPS details** | repo root `vps.md` (gitignored â€” **GitHub pe kabhi push mat karna**) |

### VPS pe redeploy (backend change ke baad)

```bash
ssh ubuntu@57.129.161.5
cd /home/ubuntu/S-Backup/sajda
git pull
cd backend && npm install --omit=dev
pm2 restart sajda-api
curl -s https://api.sajda.online/api/health
```

### VPS troubleshooting

```bash
pm2 list                    # sajda-api online hona chahiye
pm2 logs sajda-api          # crash logs
pm2 restart sajda-api       # restart
sudo nginx -t && sudo systemctl reload nginx   # nginx config check
sudo certbot certificates   # SSL expiry check (auto-renew on)
```

> **SSH non-interactive** (automated scripts ke liye): Windows pe password
> prompt hang hota hai. `SSH_ASKPASS` + `SSH_ASKPASS_REQUIRE=force` use karo.

---

## 1. Kya kahan deploy hota hai?

| Cheez | Kahan jati hai | Kaise |
|---|---|---|
| **Backend** (`/backend` folder, Node.js) | **OVH VPS** (see Section 0) | SSH â†’ `git pull` â†’ `pm2 restart sajda-api` |
| **Privacy policy site** | **Railway** (`policy-production-980a`) | GitHub push â†’ auto-deploy |
| **Flutter app** (Android) | **Play Console** | Local build â†’ AAB upload â†’ review |
| Frontend web | Kuch nahi | App hi sab kuch hai |

**Live backend URL:** `https://api.sajda.online/api`
**Health check:** `GET /api/health` â†’ `200` hona chahiye

**App endpoint source:** `lib/config.dart` (`AppConfig.apiBaseUrl`) â€”
sab API calls (`api_client.dart`, `auth_service.dart`) isi se aati hain.
Naya domain lage to sirf `config.dart` badlo.

---

## 2. Saved credentials & IDs

**Railway account:** tehryym01@gmail.com (workspace: tehryym01-hub's Projects)

**API token:** repo root ki `.railway_token` file mein hai.
- Ye file `.gitignore` mein hai â€” **GitHub par kabhi push nahi hogi** (token leak = poora account hack)
- `backend/.env` wala purana token **DEAD** hai â€” use mat karna

**IDs (constants â€” ye kabhi nahi badalte):**

| Cheez | ID |
|---|---|
| Workspace | `ea6d93be-f71f-4f4d-aafd-2edfd30b0cb1` |
| Project (sajda-prod) | `b9aafb99-a3b1-487c-bbe5-556f016536d9` |
| Environment (production) | `7034f999-8ac3-4c5b-b079-f59a5b582f64` |
| Service (backend) | `a0c5e65a-849c-4eba-b7d4-6f7b38ac84f2` |

**GraphQL endpoint (sirf ye wala chalega):**
```
https://backboard.railway.app/graphql/v2
```
> âš ï¸ `/graphql` (bina v2) **404** deta hai. CLI (`railway up` etc.) token env var ke sath
> "Unauthorized" deta hai â€” **CLI use mat karo, seedha API scripts use karo.**

---

## 3. Ready-made scripts (repo mein maujood)

Repo: `scripts/railway/` â€” token khud `.railway_token` se parhte hain.

```powershell
# Naya deploy trigger karo (bina sha = latest commit)
node scripts/railway/deploy.mjs

# Kisi KHUS commit ko deploy karna ho to (sha = git rev-parse HEAD ka output)
node scripts/railway/deploy.mjs 80628665ee642d0d39936ff43dc4a8cba48f8ccc

# Recent deployments ki list
node scripts/railway/status.mjs

# Latest deployment ko SUCCESS/FAILED hone tak watch karo (~40s poll)
node scripts/railway/status.mjs --watch

# Kisi deployment ke logs (crash diagnose karne ke liye)
node scripts/railway/logs.mjs <deploymentId>     # short id (8 letters) bhi chalta hai
```

---

## 4. Flow A â€” Backend deployment (90% cases)

Backend change kiya? Bas:

```powershell
git add <files>
git commit -m "fix: ..."
git push origin main
```

Phir VPS pe (ya seedha VPS pe git pull):

```bash
ssh ubuntu@57.129.161.5
cd /home/ubuntu/S-Backup/sajda && git pull
cd backend && npm install --omit=dev && pm2 restart sajda-api
```

Verify:
```powershell
Invoke-WebRequest -Uri "https://api.sajda.online/api/health" -UseBasicParsing
```

> **Railway (legacy â€” sirf policy site ke liye):** Neeche ke Railway sections
> ab sirf `policy-production-980a` (privacy policy site) ke liye applicable
> hain. Backend ab VPS pe hai (Section 0).

---

## 5. Deploy FAIL ho jaye to

- **Ghabrao mat:** fail hui deployment live app ko nahi badalti â€” **purana chalta rehta hai.**
- Logs dekho:
```powershell
node scripts/railway/status.mjs            # FAILED deployment ka id note karo
node scripts/railway/logs.mjs <id>         # asli error yahan hoti hai
```
- Fix karo â†’ commit â†’ push â†’ phir se.

---

## 6. Troubleshooting â€” aaj ke asli sabak

| Masla | Wajah | Hal |
|---|---|---|
| `service unavailable` healthcheck attempts, deploy FAILED | Server boot par crash (e.g. kisi file ne aisa import kiya jo service export nahi karti) | `logs.mjs` â€” crash ka exact file/error dikhta hai |
| `CLI Unauthorized` despite token | Railway CLI token env var theek se nahi leta | CLI chhoro, scripts use karo |
| GraphQL `404` | Ghalat endpoint (`/graphql`) | `/graphql/v2` use karo |
| `Unknown argument "serviceId" on field "Query.deployments"` | Ghalat query shape | Deployments **environment(id) ke andar** se lo |
| `Field "meta" must not have a selection` | `meta` scalar hai, sub-fields nahi | Sirf `meta` likho, `meta { ... }` nahi |
| `Cannot query field "edges" on type "Log"` | `deploymentLogs` flat list deta hai | `{ message severity timestamp }` â€” edges nahi |
| Deploy SUCCESS par purana code live | `latestCommit: true` ne cached purana sha liya ("reason: redeploy") | Explicit `commitSha` pass karo |
| Local test mein server 30s tak kuch nahi karta | `connectDB()` pehle hoti hai â€” bina MongoDB ke wo ~30s timeout lagati hai | Wait karo ya local Mongo chalao; deploy se pehle `node --check` + import-graph test kaafi hai |

---

## 7. Flutter app release (Play Console)

```powershell
# 1. Version badlo (pubspec.yaml):  version: 1.0.3+4   (hamesha dono barhao)
# 2. Build
flutter build appbundle --release
# 3. Output: build\app\outputs\bundle\release\app-release.aab
# 4. Play Console â†’ Production â†’ Create release â†’ AAB upload
```
Release ke pehle:
```powershell
flutter analyze
flutter test
```
> Note: Railway/Play Console ek doosre se koi taluq nahi â€” backend ka deploy
> review ke doran bhi safe hai, chal rahi build par asar nahi hota.

---

## 8. Naya Railway token banana (agar purana ghair-maujood ho jaye)

1. https://railway.com â†’ login (tehryym01@gmail.com)
2. Workspace Settings â†’ **Tokens** (ya Account Settings â†’ API Tokens)
3. Naya token banao, copy karo
4. Repo root ki `.railway_token` file mein paste kar do â€” bas, scripts phir chalengi

---

## Quick cheat-sheet

```powershell
# Backend deploy (sab se common) â€” VPS
git push origin main
ssh ubuntu@57.129.161.5 "cd /home/ubuntu/S-Backup/sajda && git pull && cd backend && npm install --omit=dev && pm2 restart sajda-api"

# Health check
curl https://api.sajda.online/api/health

# Crash hua?
ssh ubuntu@57.129.161.5 "pm2 logs sajda-api --lines 50"

# App release
flutter analyze; flutter test; flutter build appbundle --release
```
