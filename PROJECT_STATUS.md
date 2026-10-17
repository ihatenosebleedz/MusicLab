**Last updated:** 2026-10-16 (Phase 2 in progress)
**Current phase:** Phase 2 — Production polish (13-step engagement)
**Next step:** Real-amdl end-to-end verification on Gentoo (owner approval
required — real download). Everything else deferred to `todo.md`.
Steps 7–8 are **deployed and verified** on the live server.

---

## Phase 2 status (13-step plan)

- **Step 1 — Audit:** COMPLETE (reported, user-approved).
- **Step 2 — Backend test baseline:** COMPLETE (6/6 passing).
- **Step 3 — Remove demo data + honest states:** COMPLETE.
- **Step 4 — Live search (debounce + cancellation):** COMPLETE.
- **Bugfix — search returned nothing:** COMPLETE (attribute-less relationship
  stubs broke decoding; fixed in `AppleMusicCore` + regression test).
- **Step 5 — Onboarding + persistence:** COMPLETE.
- **Step 6 — Theming + app icon:** COMPLETE. Pride-rainbow app icon (single
  icon, no alternates per user decision) + persistent **accent picker** in
  Settings (7 accents incl. Pride), applied app-wide.
- **Step 7 — Backend `/logs`:** COMPLETE + **DEPLOYED** (2026-10-16). Authenticated,
  paginated, redacted `GET /logs` (backend file + per-job amdl output + wrapper).
  Live: `GET /logs` → 401 unauth, 200 authed with redacted lines.
- **Step 8 — Destination mapping (wrong-folder fix):** COMPLETE + **DEPLOYED**
  (2026-10-16). Server-side id→path map; per-destination amdl working dir rewrites
  only the save-folder keys. Live `.env`: `DESTINATIONS={bryon,elijah}`,
  `DEFAULT_DESTINATION=bryon`; `GET /destinations` returns both with `bryon`
  default. DB columns `destination_id`/`destination_path` migrated.
- **Steps 9–13:** DEFERRED → `todo.md`.

## App wiring (2026-10-16)
- **Logs viewer:** `JobDetailView` fetches `GET /logs?jobId=…` (refresh +
  embedded-tail fallback).
- **Destination picker:** `SettingsView` gains a single-default **Download
  Destination** section; `AppState` loads `GET /destinations`, persists the
  choice, and sends `destinationId` on `POST /jobs`.
- iOS core tests **27/27**; `xtool dev build` clean; unsigned IPA taildropped.

## Test status
- iOS core unit tests: **36/36** (`SearchDebouncerTests`, `ServerConfigTests`,
  decoder regression, destination/logs DTO decoding, `DeepLinkTests`, etc.).
- Backend: **24/24** (`api` 6, `logs` 7, `destinations` 8, `jobRunner` 4).
- `xtool dev build`: success.

## Ops
- **Steps 7–8 deployed to Gentoo (2026-10-16):** backed up `src` →
  `src.bak-20261016-062344`; copied 6 modified + 3 new `src` files, 2 test files,
  `package.json`; appended `DESTINATIONS`/`DEFAULT_DESTINATION`/`LOG_FILE`/
  `WRAPPER_LOG_FILE` to `.env`; `doas rc-service musiclab-backend restart` OK;
  DB auto-migrated (`destination_id`/`destination_path`). Verified `/health`,
  `/destinations`, `/logs` (401 unauth). **Excluded from deploy:** `catalog.js`
  (unrelated local playlist/artist edit), `scripts/setup.js`, local `data/jobs.db`.
- **Do not run `npm test` on the live host:** tests assume a local env; the
  job-completion test hangs in `verifying` against the real Navidrome. The suite
  is green **locally 20/20** on identical code; live verification is via the
  endpoints + a real-amdl run.
- Minor pre-existing cosmetics (not fixed): `/health` shows a doubled amdl path
  (`…/apple-music-downloader//home/nbz/apple-music-downloader/amdl`); OpenRC init
  line 3 logs `Lab: command not found`.
- Deleted the wrongly-placed import on Gentoo:
  `/mnt/media/Music/Riversmelt, RXDL & MOGGER/` (59 MB, only stray top-level
  dir). Real libraries `Bryon's Library` / `Elijah's Library` untouched.
- Root-cause fix for wrong-folder downloads is Step 8 (destination mapping) —
  now deployed, pending real-amdl confirmation.

## Step 3 summary (2026-10-16)

Removed fabricated local-job states and replaced fake UI claims with honest,
server-backed / connection-aware states.

**Changed:**
- `AppState.submitImport` — offline branch no longer fabricates a fake
  `job-XXXX`; shows honest "Server offline — connect in Settings" and returns.
- `AppState.submitUrlImport` — same; validation still runs, but no fake local
  job and the import sheet is not falsely dismissed while offline.
- `AppState.retryJob` — was flipping local state only (next poll overwrote it,
  so Retry silently did nothing). Now re-submits the URL to the backend as a new
  job; honest offline/error toasts.
- `AppState.cancelJob` — offline branch no longer fakes local cancellation;
  honest "cannot cancel" toast.
- `LibraryView` — removed hardcoded green "Ready" badge and the unverifiable
  "Auto-discovery active" claim. Status badge now reflects real backend
  connection (Checking / Connected / Offline); empty state explains "Not
  Connected" with a Configure Connection action when offline.
- `QueueView` — empty queue when offline now shows a "Not Connected" empty
  state with a Configure Connection action instead of "queue is empty".

**Verification:**
- iOS core unit tests: 14/14 pass (`MusicLabCoreTests-test-runner`).
- `xtool dev build`: success (10.03s) → `MusicLab/xtool/MusicLab.app`.
- Backend tests: 6/6 pass (unchanged — Step 3 was frontend-only).
- On-device visual check of honest states: pending (iPhone not attached in this
  session); can package + send IPA on request.

## Known issues deferred (from audit)
- Destination mismatch → **FIXED in code (Step 8)**, pending deploy: amdl save
  folder is now steered per-import via a generated working dir; the server
  `DESTINATIONS`/`DEFAULT_DESTINATION` env must be set on deploy.
- No `/logs` backend endpoint → **FIXED in code (Step 7)**, pending deploy:
  authenticated, paginated, redacted `GET /logs`.
- OpenRC init file line 3 (`description=Music Lab backend`) is unquoted →
  harmless `Lab: command not found` on service start.
- Logs UI (consume `GET /logs`) + destination picker → `todo.md`.
- Ordered playlist import, UI polish, security remainder, final integration,
  deploy → `todo.md`.

## Step 7 & 8 summary (2026-10-16)

**Step 7 — `GET /logs`:** new `backend/src/logs.js` (mounted under `requireAuth`).
Paginated (`limit` 1–500, `offset`), sources = backend service file (`LOG_FILE`),
wrapper-lite file (`WRAPPER_LOG_FILE`), and per-job amdl stdout/stderr (SQLite).
`jobId=` scopes to one job. Every line goes through `redact()` (Bearer tokens,
`name=value` secrets, and exact live secrets via `auth.peekToken()`). Response:
`{ logs, page, available }`.

**Step 8 — destination mapping:** real `amdl` has no destination flag and reads
`config.yaml` from cwd. Fix = server-side id→path map + a generated
per-destination working dir (`backend/src/amdlConfig.js`) that copies the real
config and rewrites only `alac/atmos/aac-save-folder`. `GET /destinations`
(ids only) and `destinationId` on `POST /jobs` (400 on unknown). Job rows and
responses carry `destinationId`/`destinationPath` (idempotent SQLite migration).

**Verification:** backend suite **20/20**; iOS core **23/23** (untouched).
`npm test` = `node --test --test-concurrency=1 tests/*.test.js` (sequential
files avoid SQLITE_BUSY on the shared DB).
