# ARCHITECTURE SPECIFICATION (STEP 1)

> Music Lab: concrete architecture for iOS app + Node.js backend wrapping amdl + Navidrome verification.

## 1. High-level architecture

Components:
- iOS app (SwiftUI, xtool/SwiftPM): catalog search, import UI, job queue/progress, history, settings (bearer token). No Apple secrets stored in app; no direct Apple Music auth in app beyond browsing via backend proxy.
- Backend (Node.js, on Gentoo ~/musiclab-backend, run as nbz, OpenRC later): REST API authenticated by single bearer token; proxies Apple Music catalog metadata (amp-api web token mechanism used by amdl) to avoid exposing secrets to app; orchestrates amdl subprocess per job; persists job state; polls Navidrome (OpenSubsonic) to verify files appear.
- amdl (existing CLI on Gentoo): `./amdl --url <URL> [--playlist] [--json]` from repo root; reads config.yaml (exit-on-error true, writes to /mnt/media/Music); depends on wrapper-lite on 127.0.0.1:12340. No HTTP API. Output format on success (exit 0): JSON `AddedTrack[]` to stdout when `--json` used? (from STEP 0 findings; to be confirmed against actual behavior in STEP 5, but treat as contract target).
- Navidrome (0.64.2 on Gentoo :4533, OpenSubsonic on): auto-discovers files in /mnt/media/Music; backend polls only (no scan trigger). BaseUrl https://gentoo.tail29a9cb.ts.net.
- Network: Tailscale + LAN, bind backend to 0.0.0.0 (LAN/Tailscale). No public funnel exposure.

## 2. Data flow

1. User searches in iOS app → app calls backend `GET /catalog/search?q=...` (proxied catalog lookup via amp-api).
2. User selects item (album/track/playlist) → app posts `POST /jobs` with `{type, url, name?}` and bearer token.
3. Backend validates auth/token, creates job (queued), starts amdl subprocess (process group) from amdl repo root with appropriate flags; streams/collects stdout/stderr; on completion parses results.
4. Backend updates job states: queued → resolving → downloading → processing → waiting_for_navidrome → verifying → completed|failed|cancelled. amdl gives coarse completion (no byte-level %), so app shows stage ladder.
5. After amdl completes successfully, backend enters waiting_for_navidrome (with backoff), polls Navidrome OpenSubsonic (search3/getSong) until tracks appear or timeout; transitions to completed/failed accordingly.
6. iOS app polls `GET /jobs/:id` (or listens; fallback polling) to show live progress/stages.

## 3. API contract (REST)

Base URL: `http://<gentoo-lan-or-tailscale>:<port>/` (Tailscale+LAN). Auth: `Authorization: Bearer <token>` on mutating/protected endpoints (at minimum /jobs mutations; catalog/search may be protected by same token per design).

Endpoints (minimal viable):
- `GET /health` → 200 OK (no auth)
- `POST /auth/verify` (optional) or just require bearer; alternatively 401 on bad/missing.
- `GET /catalog/search?q=...&type=track|album|playlist|artist&limit=...` → paginated results (proxied from amp-api). Include artwork, ids, URLs.
- `POST /jobs` body `{type: "track"|"album"|"playlist", url: string, name?: string}` → creates job, returns job id + initial state.
- `GET /jobs` (list recent, filter by status) → array of job summaries.
- `GET /jobs/:id` → full job details (state, stage, result files, error, timestamps, navidrome verification status).
- `POST /jobs/:id/cancel` (if supported) → cancels running amdl process group; sets cancelled.
- `GET /history` → completed/failed recent.

Error model: `{error: {code, message, details?}}` with consistent codes.

## 4. Job model & states

```json
{
  "id": "uuid",
  "type": "album",
  "url": "...",
  "name": "...",
  "state": "queued|resolving|downloading|processing|waiting_for_navidrome|verifying|completed|failed|cancelled",
  "stage": "resolving|fetching|converting|tagging|moving|verifying|done|error",
  "progressHint": "coarse|none",
  "createdAt": "ISO8601",
  "updatedAt": "ISO8601",
  "startedAt": "...",
  "finishedAt": "...",
  "exitCode": 0,
  "stdoutTail": "...",
  "stderrTail": "...",
  "addedTracks": [{"title": "...", "artist": "...", "album": "...", "path": "..."}],
  "navidrome": {"verified": true, "checkedAt": "...", "matches": 3},
  "error": {...}
}
```
Notes: amdl emits `AddedTrack[]` on success with `--json` (exit 0). No byte-level progress; app shows ladder.

## 5. amdl integration details

- Run from amdl repo root: `/home/nbz/apple-music-downloader/` (CWD). config.yaml there controls behavior.
- Invocation examples: `./amdl --url <track-url> --json`; `./amdl --url <album-url> --json`; `./amdl --url <playlist-url> --json` (playlist may need `--playlist` flag depending on version; confirm in STEP 5).
- Requires wrapper-lite on 127.0.0.1:12340 (logged in). Credentials never read/stored by backend.
- `exit-on-error: true`; backend must capture non-zero exit and map to failed state with stderr tail.
- Spawn with process group (setsid) so ffmpeg children can be killed on cancel.
- Parse `AddedTrack[]` from stdout when exit 0 and `--json` used. Treat any malformed JSON as failure with captured output.

## 6. Navidrome verification

- Method: OpenSubsonic REST API (polling only). Use existing Navidrome 0.64.2 endpoint conventions; auth via OpenSubsonic credentials or token as configured (Navidrome UI uses bryon/admin; for API use API key if available? Or standard user auth). We need to determine auth method from config in STEP 5/11, but design assumes token/API key or basic auth over HTTPS/Tailscale.
- Strategy: after amdl success, wait with exponential backoff (e.g. 2s,4s,8s,... up to timeout like 120-300s) and query for each AddedTrack (search3 by title+artist or getSong if we have id) until all appear or timeout. Consider Navidrome scan latency; auto-discovery means no explicit scan call.
- Verification passes only when expected tracks are found; else retry until timeout → failed (or partial per policy).
- No rescan trigger. Polling only.

## 7. iOS app architecture (xtool/SwiftPM)

- Project: `xtool new` scaffolded in repo root as `MusicLab` (or hand-rolled). SwiftUI + async/await.
- Module split: `MusicLabCore` (models, networking, auth/storage, API client, keychain) + `MusicLabUI` (views, viewmodels). Core testable on Linux via `swift test` where possible.
- Models mirror backend API (Job, Track, SearchResult). Codable with strict decoding.
- Networking: `URLSession` + bearer token header from Keychain. Handle 401/429/network errors.
- Auth: single bearer token entered once in Settings, stored in iOS Keychain. App starts with token check.
- State: observable viewmodels per screen; job list refreshes via polling (with backoff) when queue non-empty; foreground/background handling TBD.
- UI: tabs (Discover/Search, Queue, Library/History, Settings). States: loading/empty/error/unavailable. No false success claims.
- Build: `xtool dev build` (or documented workflow). Device install via `xtool install`/`xtool dev run`. Signing handled by xtool per credentials.

## 8. Persistence & recovery

- Backend: persist jobs to disk (SQLite or JSON file) in `~/musiclab-backend/data/jobs.db` (or similar). On restart, reload queued/running jobs and resume monitoring (detect if amdl process still alive, else mark as failed/unknown with clear state).
- iOS: minimal local state (token, last viewed). Jobs are authoritative on backend.

## 9. Security & ops

- Bearer token: 32+ char random, generated server-side, never logged, never stored in repo/app binary. Rotation manual.
- Network: Tailscale+LAN only; backend binds 0.0.0.0. Consider TLS only if exposed beyond trusted LAN? D6 says Tailscale+LAN; TLS optional but recommended if traversing untrusted networks — defer to STEP 5/15.
- Secrets: no Apple credentials in app or git. amdl/wrapper-lite already configured on Gentoo.
- Process isolation: run amdl as `nbz`, process group kill on cancel, timeouts on subprocess.
- Logging: structured, no secrets; stdout/stderr tails truncated.

## 10. Testing strategy (per component)

- Backend unit: job state transitions, amdl output parsing, Navidrome polling logic (mock HTTP), auth middleware. Use Node test framework (Jest/Vitest) — choose in implementation; keep simple.
- Backend integration: fake amdl script that emits expected JSON and exits with codes; mock Navidrome endpoints.
- iOS unit: models decoding, URL parsing, API client (mock URLSession). Run on Linux where feasible via `swift test` on core module.
- E2E manual: search → submit → track job → verify file appears in Navidrome (user test). Document in TESTING.md.
- Contract tests: against real amdl behavior (STEP 5) and real Navidrome (STEP 11).

## 11. Prerequisites & open items resolved/remaining

Resolved (STEP 0): Q1-Q8 except signing detail. Remaining: signing account type (free/paid) → STEP 2 (Q7b); exact amdl flags for playlist (`--playlist`) and exact `--json` shape → STEP 5; Navidrome API auth method → STEP 5/11. All non-blocking for STEP 1.

## 12. Deliverables for STEP 1 approval

- This spec (`docs/ARCHITECTURE_SPEC.md`).
- Updated `docs/TESTING.md` with concrete test matrix (backend/iOS/unit/integration/manual) referencing the above.
- Update `docs/IMPLEMENTATION_PLAN.md` to reflect any minor refinements from spec (if needed).
- Update `docs/ARCHITECTURE_DECISIONS.md` to capture final choices (D4/D5/D6/D7 confirmed; add job states).
- Update `PROJECT_STATUS.md`: STEP 1 complete summary + next approval point (STEP 2).
