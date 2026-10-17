# MusicLab — Deferred Work

_Deferred on 2026-10-16 to fast-track the two urgent fixes (working backend logs
+ correct import folder). Source: the production-polish plan (13-step
engagement). Steps 1–8 are done._

## Deferred implementation steps

### Step 9 — Ordered playlist import (DONE 2026-10-17)
- Playlists now resolve to ordered Apple catalog tracks (`backend/src/appleMusic.js`),
  download per-song into normal artist/album folders (`backend/src/jobRunner.js`
  `resolvePlaylistSongs`), and write an order-preserving `.m3u8` inside the
  destination library (`backend/src/playlistFile.js`). Navidrome imports it via
  its file watcher. Verified end-to-end (Sad 36/36, Brawl stars 18/18, public).
- Known limitation: personal/library playlists (`p.*`) can't be resolved
  anonymously and fall back to amdl's native flat-album mode (no m3u8).

### Step 9b — Live download progress + ETA (DONE 2026-10-17)
- Backend parses amdl stdout in real time (`backend/src/amdlProgress.js`):
  `Queue x of N` (playlists), `Track x of N` (albums), `Decrypting... PP% (…, Z MB/s)`,
  `Decrypted`/`Conversion completed`. Emits percent, completed/total, throughput
  and ETA; persisted to new `jobs` columns (`db.js`) and surfaced via `GET /jobs`.
- iOS shows a live percent bar + `x/y • speed • ETA` in Queue rows and JobDetail
  (`DownloadProgressView`); polling is 1s while jobs are active, 3s when idle.
- Tests: `backend/tests/amdlProgress.test.js`; iOS `BackendDTOTests` progress cases.

### Step 10 — UI polish (DONE 2026-10-17)
- Loading skeletons in Queue/Library (`Components/SkeletonView.swift` +
  `AppState.isLoadingJobs`), toast severities (`ToastKind` + haptic feedback in
  `ContentView`), progress-bar animation, VoiceOver labels on progress/badges,
  and dead-code cleanup (`QuickImportSheet`, duplicate modifiers).
- `xtool dev build` clean. On-device visual pass still pending → folds into Step 12.

### Step 11 — Security / reliability (remainder)
- Multi-request review of auth + error paths. (Bearer token over Tailscale/LAN
  already in place; the TLS change was explicitly declined by the owner.)
- Consider rate limiting and request-body size limits on the backend.

### Step 12 — Final integration testing
- End-to-end pass on a real device against the live backend for every flow.

### Step 13 — Production readiness + deploy
- Formal release checklist, versioning, and deploy runbook. **Always requires
  explicit owner approval before touching the live Gentoo server.**

## Also deferred (surfaced while doing the logs + destination work)

- **iOS Logs screen (DONE 2026-10-16).** `JobDetailView` now fetches
  `GET /logs?jobId=…` (refresh button), falling back to the job's embedded
  stdout/stderr tails. A standalone global logs viewer is still not built.
- **iOS destination picker (DONE 2026-10-16).** `AppState` loads
  `GET /destinations`, persists the choice, and passes `destinationId` on
  `POST /jobs`; Settings has a Download Destination picker (single default).
- **Server log file paths (DONE 2026-10-16).** Live `.env` sets `LOG_FILE` and
  `WRAPPER_LOG_FILE`.
- **MV imports.** Destination steering rewrites `alac/atmos/aac-save-folder` but
  not `mv-save-folder` (music videos). Not currently reachable from the app.
