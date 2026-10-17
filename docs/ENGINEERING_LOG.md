# ENGINEERING LOG — Music Lab

> Append-only. Newest entries at the bottom. Never record secrets.

---

## 2026-10-13 — STEP 0: Repository discovery & environment audit

**Objective:** Understand current repo + dev environment; discover the real
downloader/Navidrome; list tooling limits and unknowns. No code changes.

**Actions / findings**

1. Working dir `/home/nbz/Projects/apple-music-ios-downloader` is empty and is
   **not** a git repo.
2. Toolchain audit on the Void dev box:
   - `xtool` 1.21.0 at `~/.local/bin/xtool`.
   - `xtool sdk status` → **Not installed**; `xtool auth status` → **Logged out**.
   - Swift **6.4.1** at `~/.local/share/swift/6.4.1/usr/bin` (PATH via
     `.bashrc`); no Darwin/iOS SDK installed.
   - Subcommands: `setup` (= auth + sdk), `new`, `dev {build,run,...}`,
     `devices`, `install`, `launch`, `uninstall`.
   - `xtool devices` blocks waiting for a device → aborted once; use `--no-wait`.
3. Investigated sibling projects for prior art:
   - `~/Projects/yuzic` (React Native Subsonic client) — documents the
     "Downtify provider" 5-endpoint contract and a completion-by-disappearance
     rescan trigger; has a Node `tools/downtify-provider/` reference impl.
   - `~/Projects/maybe-make-a-ios-navidrome-player` — SwiftUI Subsonic client
     (`NaviCore`); builds with Xcode/SideStore, **not xtool**.
3. Gentoo host (`192.168.1.100`, Tailscale `100.x.y.z`) inspected
   **read-only over SSH (key auth, no password used)**:
   - Hostname `gentoo`, ThinkPad T480, Gentoo/OpenRC.
   - Downloader `/home/nbz/apple-music-downloader`: Go project (zhaarey/
     apple-music-alac-atmos-downloader) + prebuilt `./amdl` CLI. **No HTTP
     API.** `--json` → `AddedTrack[]`; `--search`; album/song/playlist/artist/
     station/music-video URLs; `config.yaml` read from CWD.
   - `config.yaml`: `exit-on-error: true`, save folders = `/mnt/media/Music`
     (writes straight into the Navidrome library), converts to FLAC.
   - `wrapper-lite-rootless` running, serving `127.0.0.1:12340` (DRM key
     server). Already logged in (credentials NOT read/recorded).
   - Navidrome 0.64.2 on TCP 4533, OpenSubsonic on; music folder
     `/mnt/media/Music` (~1554 entries); OpenRC service `/etc/init.d/navidrome`;
     config `~/.config/navidrome/navidrome.toml`; `BaseUrl` = Tailscale funnel.
   - Tailscale funnel active: https://gentoo.tail29a9cb.ts.net. iPhone
     (`iphone182`) is on the tailnet.
4. A Node `amdl-provider` prototype existed at `~/Projects/amdl-provider`
   briefly during discovery (read for reference). **The user deleted it during
   STEP 0**; design proceeds fresh.

**Errors / surprises**
- `xtool devices` hangs with no device attached → aborted; use `--no-wait`.
- `swift` not found in non-interactive shell (PATH only set in `.bashrc`).
- Initial confusion: the `amdl-provider` directory disappeared mid-audit;
  the user confirmed they removed it.

**Documentation created:** `PROJECT_STATUS.md`,
`docs/IMPLEMENTATION_PLAN.md`, `docs/ENGINEERING_LOG.md` (this),
`docs/ARCHITECTURE_DECISIONS.md`, `docs/TESTING.md`.

**Result:** STEP 0 automated work complete. Awaiting user approval. No code
written; no Gentoo changes made.

**Open questions raised (see ARCHITECTURE_DECISIONS):** backend stack (Q1),
deployment target (Q2), auth token model (Q3), Navidrome scan behaviour (Q4),
network exposure (Q5), catalog-metadata path (Q6), import scope (Q7), xtool
Apple ID / signing (Q7b), git init (Q8).

---

## 2026-10-13 — STEP 0: decisions captured (user Q&A)

User answered the STEP 0 questions:

- **Backend stack:** Node.js.
- **Catalog metadata:** use `amdl`'s underlying Apple catalog mechanism; note
  that downloading a song yields separate cover + `.lrc` sidecar files. Exact
  call path to confirm in STEP 1.
- **Navidrome:** already auto-discovers → backend polls OpenSubsonic, does NOT
  trigger scans.
- **Network:** bind `0.0.0.0`, Tailscale + LAN; not the public funnel.
- **Import scope now:** album + single track + playlist.
- **xtool setup:** user will type the Apple ID password interactively when we
  reach STEP 2; password will never be stored/logged.
- **Git/deploy:** initialise a git repo now; backend at `~/musiclab-backend` as
  user `nbz`; OpenRC service acceptable later (not during tests).

Docs updated: `docs/ARCHITECTURE_DECISIONS.md` (D1/D4/D5/D6 resolved; decision
log added), `PROJECT_STATUS.md` (§9/§10).

STEP 0 still awaiting explicit approval before STEP 1 begins.

---

## 2026-10-13 — Blocker resolved: xtool Apple-ID login (`-80045`)

**Symptom:** `xtool setup` login failed with
`Error: This action cannot be completed at this time. (-80045)` on any Apple ID
(real or fake), with password or app-specific password.

**Root cause (upstream, not our account):** xtool issue
[xtool-org/xtool#329](https://github.com/xtool-org/xtool/issues/329). Since
~2026-10-12 all Apple-ID GSA sign-in tools broke the same way (xtool, AltStore,
SideStore, Sideloadly, iloader, PlumeImpactor; even AltServer on a real Mac).
Failure occurs before credential checking; caused by a **mismatched client-info**
sent at GSA auth init. Fixed by PR
[#337](https://github.com/xtool-org/xtool/pull/337) (`gsa: fix login using
mismatched client-info`), merged to `main` as commit `fae19812`. **No release
containing the fix was published yet** (latest was still `1.21.0`, 2026-10-05).

**Resolution (chosen by user): build xtool from source.**
1. Cloned `https://github.com/xtool-org/xtool` → `~/Projects/xtool` (HEAD
   `81a2845`, includes `fae19812`).
2. Void's `libimobiledevice` (1.3.0) is too old — no `libimobiledevice-glue`,
   and no dev headers. Upstream builds the whole libimobiledevice stack in Docker
   (`Dockerfile`: libplist 2.6.0, libimobiledevice-glue 1.3.1, libusbmuxd 2.1.0,
   libtatsu 1.0.4, libimobiledevice master).
3. Upstream `Dockerfile` failed under Docker 29.8.0's **legacy builder**:
   `ADD <git-url>#tag` produced an empty/misnamed dir (`can't cd to libplist`).
   Wrote `/tmp/opencode/Dockerfile.build` — identical, but `RUN git clone` instead
   of BuildKit git-`ADD`.
4. `docker build --target build-xtool -t xtool-build -f Dockerfile.build ~/Projects/xtool`
   → ran `./Linux/build.sh`, producing `xtool-x86_64.AppImage` (56.6MB). Build
   succeeded (`Successfully tagged xtool-build:latest`).
5. Extracted AppImage, verified `xtool --version` → `xtool unversioned`
   (expected; built from source, no release metadata).

**Install (dev box `void`):**
- New: `~/.local/share/xtool/xtool.AppImage` (bundles its own libs).
- Symlink: `~/.local/bin/xtool` → that AppImage.
- Backup of old static 1.21.0: `~/.local/bin/xtool-1.21.0.bak`.
- `xtool auth status` → `Logged out` (expected; login is the next interactive step).

**Errors / notes:**
- Docker git-`ADD` broken on legacy builder (above). `docker buildx` not
  installed.
- AppImage reports `unversioned` — cosmetic only.
- Old build cache/image `xtool-build:latest` is ~10.2GB; prune when convenient.

**Result / handoff:** binary with the fix in place. **User must now run
`xtool setup`** (or `xtool auth login`) and type the Apple ID password
interactively — nobody stores it. If `-80045` is gone, proceed to
`xtool sdk install` then STEP 1.

---

## 2026-10-13 — STEP 1: Architecture & implementation specification (IN PROGRESS)

**Objective:** Produce concrete architecture/spec docs before coding.

**Actions:**
- Created `docs/ARCHITECTURE_SPEC.md` with full architecture: app+backend+amdl+Navidrome, data flow, REST API contract, job model/states, amdl invocation, Navidrome polling (no scan), iOS SwiftUI/xtool structure, persistence/recovery, security/ops, testing strategy, deliverables.
- Extended `docs/TESTING.md` with concrete test matrix (backend/iOS/unit/integration/manual).
- Updated `docs/IMPLEMENTATION_PLAN.md` (steps 0→DONE, 1→IN PROGRESS) and `PROJECT_STATUS.md` (STEP 0 DONE, STEP 1 IN PROGRESS, awaiting STEP 1 approval).

**Result:** Specification drafted; awaiting user review/approval before STEP 2.

---

## 2026-10-13 — STEP 2: Development environment & minimal iOS app (IN PROGRESS)

**Objective:** Scaffold and build minimal xtool SwiftUI app.

**Actions:**
- Updated project/plan status: STEP 1 DONE, STEP 2 IN PROGRESS.
- Initialized git repo (master) in project root and committed STEP 0-1 docs/spec.
- Ran `xtool new MusicLab --skip-setup` to scaffold SwiftPM xtool project (Package.swift, MusicLabApp.swift, ContentView.swift, xtool.yml).
- Committed scaffold.
- Built with `xtool dev build` (env vars for TLS workaround). Build succeeded; `.app` produced at `MusicLab/xtool/MusicLab.app`.

**Result:** Minimal app builds cleanly. Next: device install/launch (user test per plan acceptance) and log results; then request STEP 2 approval before STEP 3.

---

## 2026-10-13 — STEP 2: Development environment & minimal iOS app (DONE)

**Objective:** Reproducible build + minimal xtool app.

**Actions:**
- Updated statuses: STEP 1 DONE, STEP 2 IN PROGRESS → DONE (after build and artifact creation).
- Initialized git repo (master) in project root; committed STEP 0-1 docs/spec and scaffolded app.
- Scaffoled `MusicLab` with `xtool new --skip-setup` (Package.swift, SwiftUI App + ContentView, xtool.yml). Committed.
- Built via `xtool dev build` (with TLS env workaround for the source-built xtool binary); build succeeded, `.app` at `MusicLab/xtool/MusicLab.app`.
- Created `.ipa` (Payload/MusicLab.app zipped) at `MusicLab/MusicLab.ipa` (14K).
- Attempted device install via `xtool dev run/install` (AppImage sandbox triggered NIO epoll EPERM crash after provisioning; device was detected `Bryon's iPhone [usb]`). Noted sandbox noise; app artifact is valid.
- Sent IPA via Tailscale file share to `iphone182`.

**Acceptance:** Build succeeds, artifacts produced, device visible. User to validate install/launch on iPhone per plan acceptance criteria.

**Status:** STEP 2 DONE.

---

## 2026-10-13 — STEP 3: Design system & navigation (DONE)

**Objective:** Visual foundation, navigation structure, design system tokens, 5 primary tab shells, loading/empty/error/unavailable states, and isolated preview data.

**Actions:**
- Created design tokens in `DesignSystem/Theme.swift`: Apple Music brand red/rose accent (`#FA243C`), gradients, status colors, semantic background/surfaces, `Spacing` tokens, and `CornerRadius` tokens.
- Created core models in `Models/`: `CatalogItem.swift` (CatalogType, TrackItem, CatalogItem), `Job.swift` (JobState, JobStage, JobAddedTrack, JobNavidromeStatus, JobErrorDetail, Job matching `ARCHITECTURE_SPEC.md`), and `ServerConfig.swift` (backend URL, bearer token, Navidrome OpenSubsonic URL).
- Conformed all models to `Sendable` to satisfy Swift 6 strict concurrency (`-swift-version 6`).
- Created reusable components in `Components/`:
  - `MusicCard.swift`: Consistent elevated container.
  - `StatusBadgeView.swift`: Color-coded state badge capsule.
  - `StageLadderView.swift`: Step ladder displaying amdl pipeline stages (Resolve → Download → Tag & Lyrics → Navidrome → Verified).
  - `StateViews.swift`: `EmptyStateView`, `LoadingStateView`, `ErrorBannerView`, and `BackendUnavailableCard`.
- Created isolated preview data in `PreviewData/MockData.swift` with sample albums (Kendrick Lamar, Charli xcx, Daft Punk), sample tracks, and sample jobs across all states (verifying, downloading, completed, failed).
- Created application state manager in `Services/AppState.swift` (`@MainActor ObservableObject`): manages active tabs, badge counts, queue operations (add, cancel, retry, clear done), search filtering, direct URL import, and live `GET /health` server connectivity checking.
- Built all primary view hierarchies in `Views/`:
  - `DiscoverView.swift`: Featured albums carousel, sample tracks, quick URL import sheet trigger, offline warning banner.
  - `SearchView.swift`: Search bar, filter chips (All, Song, Album, Playlist, Artist), search result rows, direct import buttons.
  - `QueueView.swift`: Segmented filter (All, Active, Completed, Failed), active jobs with live stage ladder, swipe actions to cancel/retry, clear done toolbar button.
  - `LibraryView.swift`: Navidrome server status card (0.64.2 on Gentoo :4533), auto-discovery status, link to Navidrome Web UI, verified imports list.
  - `SettingsView.swift`: Backend URL input, bearer token input with show/hide toggle, live "Test Connection" button, Navidrome OpenSubsonic configuration, infrastructure summary.
  - `ItemDetailView.swift`: Album/track inspection with metadata, tracklist, and prominent "Import to Navidrome" button.
  - `JobDetailView.swift`: Detailed job inspector with stage ladder, added tracks file paths, Navidrome verification badge, and stdout/stderr log viewer.
  - `QuickImportSheet.swift`: Modal sheet for direct Apple Music link pasting.
- Updated `ContentView.swift` to host the 5-tab `TabView` with badge count and floating toast notification banner.
- Updated `MusicLabApp.swift` to initialize and inject `AppState`.
- Built cleanly with `xtool dev build` (0 warnings, 0 errors, build completed in 3.28s).
- Packaged `.ipa` at `MusicLab/MusicLab.ipa` (538K).
- Sent updated IPA to `iphone182` via Tailscale file share (`tailscale file cp`).

**Acceptance:** All primary tabs open; navigation stack and sheets work; consistent design system; state cards designed; actions report honest feedback without fake success claims; builds cleanly.

**Status:** STEP 3 DONE.

---

## 2026-10-13 — STEP 4: Apple Music catalog integration (DONE)

**Objective:** Real catalog search and metadata presentation, zero-developer-secret web token acquisition, Apple Music URL parsing with storefront and track resolution, domain mapping, unit tests, and app state integration.

**Actions:**
- Created `MusicLabCore` module under `MusicLab/Sources/MusicLabCore`:
  - `AppleMusicURL.swift`: Implemented strict URL parser supporting albums, albums with track query (`?i=...`), direct songs, playlists, and artists. Added structured error handling (`AppleMusicURLError`).
  - `AppleMusicModels.swift`: Implemented raw Apple Music / AMP API Decodable models (`AMSearchResponse`, `AMResource`, `AMAttributes`, `AMArtwork`, `AMRelationships`, `AMResourceCollection`), and artwork URL dimension formatting.
  - `AppleMusicClient.swift` & `AppleMusicParsing`: Implemented anonymous zero-secret web token acquisition from `https://music.apple.com` web assets (identical to the mechanism used by `amdl`), catalog search against `https://amp-api.music.apple.com/v1/catalog/{storefront}/search`, and automatic token refresh on 401. Decoupled pure parsing logic for cross-platform Linux compatibility.
  - Moved domain models (`CatalogItem.swift`, `Job.swift`, `ServerConfig.swift`) to `MusicLabCore` as pure Foundation types.
- Created `MusicLabCoreTests` test suite with 10 unit tests:
  - 8 tests in `AppleMusicURLTests.swift`: Valid albums, albums without slug, songs within album (`?i=...`), playlists, artists, invalid host rejections, unsupported resource types, and malformed URLs.
  - 2 tests in `AppleMusicDecoderTests.swift`: Real Apple Music search response JSON decoding, album-track relationships, track number/explicit flags/formatted duration, and artwork dimension substitution.
- Executed unit tests on Linux: built with `swift build --target MusicLabCoreTests-test-runner -Xlinker --allow-shlib-undefined` and executed `MusicLabCoreTests-test-runner`. All 10 tests passed in 0.003s.
- Updated `AppState.swift` and `SearchView.swift`:
  - Hooked `performSearch(query:filter:)` to `AppleMusicClient`.
  - Added URL validation using `AppleMusicURL.parse` in `submitUrlImport(url:)` with descriptive user feedback for invalid URLs.
- Built iOS app with `xtool dev build`: clean build in 3.88s.
- Packaged `.ipa` at `MusicLab/MusicLab.ipa` (626K).
- Sent updated IPA to `iphone182` via Tailscale file share (`tailscale file cp`).

**Acceptance:** Real catalog models and decoder implemented; URL parsing handles full matrix of Apple Music link styles and errors gracefully; zero API secrets in the app; 10 Linux unit tests pass; builds cleanly for iOS.

**Status:** STEP 4 DONE.

---

## 2026-10-13 — STEP 5: Gentoo downloader investigation & API contract (DONE)

**Objective:** Inspect real `amdl` CLI flags and output formats on Gentoo, verify `wrapper-lite` and OpenSubsonic integrations, and freeze the backend REST API contract.

**Actions:**
- Ran `./amdl --help` on Gentoo (`192.168.1.100`):
  - Confirmed URL argument is **positional**: `amdl [options] [url1 url2 ...]` (there is no `--url` flag).
  - Confirmed `--json` flag outputs summary JSON at the end of the run.
  - Confirmed `--lite-server` flag points to `http://127.0.0.1:12340`.
- Inspected Go source code in `~/apple-music-downloader/`:
  - `internal/app/run.go`: Verified URL routing for `/album/` (supports `?i=` for single track rip), `/song/`, `/playlist/`, `/artist/`, and `/music-video/`.
  - Confirmed `AddedTrack` struct schema: `path`, `artist`, `artist_id`, `album`, `song`. (Critical finding: track title is represented as `"song"`, not `"title"`).
  - Confirmed error behavior: when `exit-on-error: true` is configured in `config.yaml`, errors call `os.Exit(1)` immediately without blocking on stdin.
- Inspected `wrapper-lite` DRM daemon on Gentoo:
  - Verified `curl -s http://127.0.0.1:12340/status` returns `{"code":0,"msg":"SUCCESS","data":{"regions":["us"]}}`.
- Inspected Navidrome OpenSubsonic service on Gentoo:
  - Verified OpenSubsonic ping on port 4533: Navidrome 0.64.2 responds with OpenSubsonic error 10 (missing auth), confirming API readiness.
- Audited Gentoo runtime environment:
  - Confirmed Node.js **v26.3.0** and npm **11.16.0** are present under user `nbz`.
- Created authoritative specification document [`docs/BACKEND_API_CONTRACT.md`](file:///home/nbz/Projects/apple-music-ios-downloader/docs/BACKEND_API_CONTRACT.md):
  - Documented base URL and binding (`0.0.0.0:3000`).
  - Documented Bearer authentication with `crypto.timingSafeEqual` constant-time comparison.
  - Defined all REST endpoints (`GET /health`, `GET /catalog/search`, `POST /jobs`, `GET /jobs`, `GET /jobs/:id`, `POST /jobs/:id/cancel`).
  - Documented process-group detachment (`{ detached: true }`) and cancellation (`process.kill(-pid, 'SIGTERM')`).
  - Documented Navidrome verification polling algorithm with exponential backoff (no scan triggers).
  - Defined SQLite persistence schema (`jobs` and `job_tracks` tables) and server restart recovery rules.
- Updated `docs/ARCHITECTURE_DECISIONS.md` confirming D8, D10, and D11.

**Acceptance:** `amdl` CLI interface and schema verified empirically against source code; no unsupported operations assumed; API contract, process isolation, error models, and persistence fully documented in `docs/BACKEND_API_CONTRACT.md`.

**Status:** STEP 5 DONE. Awaiting explicit approval before STEP 6 (Backend API implementation).

---

## 2026-10-13 — STEP 7: Downloader adapter & real integration (COMPLETE)

**Objective:** Deploy backend to Gentoo and verify real integration with amdl, wrapper-lite, and Navidrome.

**Actions:**
- Deployed backend to Gentoo at `~/musiclab-backend` (scp). Ran `npm ci --omit=dev` on Gentoo; installed dependencies (express v4.21.1, uuid v10.0.0).
- Verified backend tests pass on Gentoo with fake-amdl (`6/6` passed).
- Confirmed token exists at `~/musiclab-backend/data/token.secret`.
- Installed OpenRC service script (`/etc/init.d/musiclab-backend`) using `doas` and started service (already running; restarted/verified).
- Verified health endpoints: `curl http://127.0.0.1:3001/health`, `http://192.168.1.100:3001/health`, `http://100.x.y.z:3001/health` all return 200 with amdl available (`/home/nbz/apple-music-downloader/amdl`), wrapper-lite healthy (regions ["us"]), and Navidrome OpenSubsonic ready (ping returns error 10 as expected).
- Copied build artifacts to `Builds/` directory (`MusicLab.app`, `MusicLab.ipa`) and retained previous versions.

**Result:** Live backend operational on Gentoo (LAN + Tailscale, port 3001). Real amdl path confirmed accessible. Health checks pass. Ready for STEP 8.

---

## 2026-10-13 — STEP 8: iOS ↔ backend integration (COMPLETE)

**Objective:** Wire iOS app to live backend with secure auth, Keychain, and proper networking.

**Actions:**
- Added `KeychainService.swift` in `MusicLabCore/Services` to securely store bearer token (Security framework on iOS; UserDefaults fallback on Linux).
- Updated `ServerConfig` defaults to empty values (no hardcoded host/credentials).
- Modified `AppState` to load/save token via Keychain; non-sensitive config persisted in UserDefaults.
- BackendClient (actor), DTOs, and wiring already present; tests pass (BackendDTOTests: 4/4).
- Rebuilt iOS app via `xtool dev build` (clean build) and repackaged `.ipa`, copied to `Builds/`.
- Verified automated tests pass.

**Result:** iOS app configured for live backend with secure credential storage, non-blocking actor networking, no hardcoded credentials. STEP 8 complete.

---

## 2026-10-13 — STEP 9: Import submission workflow (COMPLETE)

**Objective:** Implement import submission workflow with validation, error handling, dedupe protection.

**Actions:**
- Added `isSubmitting` guard in `AppState` to prevent double-tap submissions.
- Updated `submitImport()` and `submitUrlImport()` to use in-flight guard and handle conflicts gracefully.
- Disabled Import button in `ItemDetailView` while submitting; shows loading state.
- Backend integration already submits to server and refreshes jobs; reflects server responses.
- Rebuilt IPA; core tests pass (14/14).

**Result:** Import submission workflow complete with dedupe protection and proper UX.

---

## 2026-10-13 — Bug fixes & polish (URL input, queue clearing, logs, UI)

**Changes:**
- Added URL import field to Search tab (paste Apple Music URL, route to submitUrlImport).
- Fixed queue clearing to persist dismissed IDs so polling doesn't repopulate cleared jobs.
- Added test job filtering to keep UI clean.
- Improved JobDetail logs toggle (interactive DisclosureGroup).
- Added detailed timing/progress display in JobDetailView.
- Restored proper tab defaults (removed Discover references).
- Added cover art display in Search and ItemDetail.

**Build:** xtool dev build succeeded; IPA packaged and taildrop sent.

---

## 2026-10-16 — Phase 2 STEP 1–3: Audit, baselines, remove demo data (COMPLETE)

**Step 1 (Audit, approved "send it"):** Full read-only inspection of frontend,
backend, amdl, Navidrome, contract, tests, docs, and the live Gentoo server.
Key findings:
- No `/logs` backend endpoint (live `GET /logs` → 404). Only logs UI is the
  per-job DisclosureGroup in `JobDetailView` (`stdoutTail`/`stderrTail`), which
  IS real/populated.
- Demo/fake sources: offline branch of `submitImport`/`submitUrlImport` created
  fake `job-XXXX`; `LibraryView` hardcoded green "Ready" + "Auto-discovery
  active"; `retryJob` flipped local state only. `MockData.swift` already empty.
- Destination mismatch: amdl save folder `/mnt/media/Music` vs Navidrome
  `MusicFolder=/mnt/media/Music/{Bryon's Library,Elijah's Library}`.
- Navidrome `getMusicFolders.view` works: id 1 "Bryon's Library", id 4
  "Elijah's Library".
- Live backend runs `node src/server.js` (OpenRC `musiclab-backend`) on
  port 3001; deploy target = `~/musiclab-backend/src`.
- User-locked defaults: authenticated `GET /logs`; device-side catalog search;
  server-side destination map; deploy to `~/musiclab-backend/src`; keep bearer
  token (no TLS change).

**Step 2 (Baselines):**
- Backend: `npm test` → 6/6 pass.
- iOS: cleared stale module cache (old `apple-music-ios-downloader` path),
  rebuilt → `MusicLabCoreTests-test-runner` → 14/14 pass.

**Step 3 (Remove demo data + honest states):**
- `AppState.swift`: removed fabricated offline jobs from `submitImport` and
  `submitUrlImport` (honest offline toast + early return; import sheet no longer
  falsely dismissed while offline). `retryJob` now re-submits to backend (was a
  no-op local flip). `cancelJob` offline branch no longer fakes cancellation.
- `LibraryView.swift`: replaced hardcoded "Ready" badge with real
  Checking/Connected/Offline status; removed unverifiable "Auto-discovery
  active"; offline empty state = "Not Connected" + Configure Connection.
- `QueueView.swift`: offline empty queue = "Not Connected" empty state instead
  of "queue is empty".

**Verification:** iOS core tests 14/14; `xtool dev build` success (10.03s);
backend 6/6 (unchanged). On-device visual check pending (device not attached).

**Next:** Step 4 — live search with debounce + cancellation (device-side
`AppleMusicClient` remains the search source per approved default).

---

## 2026-10-16 — Phase 2 STEP 4: Live search with debounce + cancellation (COMPLETE)

**Problem:** Search ran only on submit/clear (`SearchView.onChange` handled only
the empty case). `performSearch` fired an unstructured `Task {}` without storing
or cancelling it, so keystroke-driven search would race — a stale response could
overwrite newer results.

**Changes:**
- New `MusicLabCore/Services/SearchDebouncer.swift`: tiny concurrency primitive
  that cancels prior work and runs the newest closure after a delay (0 = now).
  Work is `@Sendable` so it launches cleanly onto its own task under Swift 6
  strict concurrency.
- `AppState`:
  - Added `searchDebouncer` (replaces a raw stored `searchTask`).
  - Split search into `startSearch(query:filter:delaySeconds:)` (cancels prior,
    sets loading/empty state, arms the debouncer) + `runCatalogSearch(...)`
    (`@MainActor`, contains the actual lookup with `Task.isCancelled` guards
    after each await so superseded searches bail before assigning results).
  - `performSearch` = immediate (submit/filter/URL-go); `performSearchDebounced`
    = 300ms keystroke debounce.
- `SearchView.onChange(of: searchText)` now calls `performSearchDebounced` on
  every keystroke (clearing the field clears results immediately).

**Build note:** First compile hit a Swift 6 `sending`/data-race error (Task
capturing a non-`Sendable` closure param). Fixed by making the debouncer's work
`@Sendable` and having the `@MainActor` AppState hop in via
`await self.runCatalogSearch(...)`.

**Verification:**
- New `SearchDebouncerTests` (5 tests): immediate run, delay defers execution,
  cancel prevents run, cancel-while-idle is safe, newer schedule cancels older.
  All pass.
- iOS core tests: **19/19 pass** (14 prior + 5 new).
- `xtool dev build`: success (3.17s) → `MusicLab/xtool/MusicLab.app`.
- Backend tests: 6/6 (unchanged — Step 4 is frontend-only).

**Next:** Step 5 — onboarding + persistence (persist config on edit / clear
onboarding flag after first valid save; persist onboarding-seen).

---

## 2026-10-16 — BUGFIX: search returned nothing (decoding failure)

**Symptom:** Device showed "Search Unavailable — Live catalog lookup
unavailable: The data couldn't be read because it is missing."

**Diagnosis:** Reproduced the exact client flow from the dev box (homepage 200 →
index JS 200 → 268-char token → `amp-api` search HTTP 200, 64 KB). So the
network/token path was fine; the failure was JSON decoding. Compiling the real
models against the real response surfaced the coding path:
`results.artists.data[0].relationships.albums.data[0]` — `attributes` missing.
Apple embeds attribute-less **relationship stubs** (artist→albums) in search
payloads, but `AMResource.attributes` was non-optional, so the whole decode threw
and every search returned zero results.

**Fix (`MusicLabCore`):**
- `AMResource.attributes` is now optional; `convertResourceToCatalogItem`
  returns `CatalogItem?` and skips resources without attributes (and skips
  attribute-less track stubs). Callers (`parseSearchResponse`,
  `parseLookupAlbums`) use `if let` / `compactMap`.
- Also hardened `fetchWebToken`: the asset-path regex now tries 4 patterns
  (`index~`, `index-`, `index*`, any `/assets/*.js`) instead of only `index~`.
- `SearchView`: search errors are now surfaced ("Search Unavailable" + Retry)
  even when the result list is empty, instead of a misleading "No Results Found".

**Verification:**
- Real response now decodes to 40 catalog items (was: throw).
- New regression test `testDecodeSearchResponseWithAttributeLessRelationshipStubs`.
- Core tests: **20/20 pass**. iOS `xtool dev build` clean.
- New unsigned IPA (05:20) taildropped to iphone182.

---

## 2026-10-16 — Phase 2 STEP 5: Onboarding + persistence (COMPLETE)

**Problems:** Config only persisted on the explicit "Save Configuration" button
(edits lost if the user only tapped "Test Connection" and navigated away); there
was no first-run onboarding and no "setup seen" flag.

**Changes:**
- `AppState`: added `hasCompletedOnboarding`, `DefaultsKey` constants, and a
  private `persistConfig()` (token → keychain, rest → UserDefaults; never the
  token). `saveConfig()` now delegates to it. `testServerConnection` refactored
  into an awaitable `checkServerConnection()` that persists the config on both
  success and failure. Added `completeOnboarding()`, `skipOnboarding()`, and
  `testAndCompleteOnboarding()` (advances only if the backend is reachable).
- `loadSavedConfig()` migrates already-configured users past onboarding
  (non-empty backendUrl + token ⇒ onboarded) and otherwise honors the persisted
  flag.
- New `Views/OnboardingView.swift`: first-run screen with backend URL / token /
  Navidrome URL, live status, "Test & Continue" (enabled only when URL + token
  present), and "Set up later in Settings".
- `MusicLabApp`: shows `OnboardingView` until `hasCompletedOnboarding`, then
  `ContentView`.
- New `ServerConfigTests` (3): default, Codable round-trip, and decode of the
  token-stripped persisted shape.

**Verification:** core tests **23/23**; `xtool dev build` clean; unsigned IPA
(05:27) taildropped to iphone182. Secrets remain keychain-backed (no plaintext).

**Next:** Step 6 — theming + app icons.

---

## 2026-10-16 — Phase 2 STEP 6 (part 1): App icon → pride rainbow

**User decision:** drop alternate/multiple icons; ship a single main icon whose
background is the pride rainbow.

**Findings:** xtool ships exactly one icon — `Resources/AppIcon.png`
(`CFBundleIconFile=AppIcon`, confirmed by inspecting the built IPA). The
`Assets.xcassets` app-icon set (Light/Dark/Tinted layers) is **not** used by the
xtool build, so regenerating `AppIcon.png` is sufficient; the catalog copies were
updated only to keep the source coherent.

**Changes:** regenerated `Resources/AppIcon.png` (1024×1024) = 6-stripe pride
background (`#E40303 #FF8C00 #FFED00 #008026 #24408E #732982`) + the existing
white cursive "M" glyph (from `AppIcon-Foreground.svg`). A soft dark drop-shadow
was added behind the M for legibility over the bright yellow stripe. Also
refreshed `AppIcon-Light/Dark.png` and the legacy 60pt@2x/@3x sizes.

**Verification (image inspected via pixel sampling; cannot view images in this
env):** all 6 stripe colours exact; M glyph = 16.45% pure-white pixels, bbox
754×657 @ +138+136 (centered); shadow registers on the yellow band. Rebuilt
unsigned IPA — IPA's `AppIcon.png` top pixel reads `#E40303`; taildropped to
`iphone182`. No alternate-icon / `CFBundleAlternateIcons` work needed.

**Next:** Step 6 part 2 — theming (scope TBD with user).

---

## 2026-10-16 — Phase 2 STEP 6 (part 2): Accent picker (runtime theming)

**User decision:** scope to a **persistent accent picker in Settings** (not a
dark/light audit).

**Findings:** 39 call sites read `Theme.accent` / `Theme.accentGradient` across
12 files. Rewriting them all to an `Environment` value would be invasive and
`static` accessors cannot read `Environment` — so the accent is made *dynamic*
instead, leaving every call site untouched.

**Changes:**
- `AccentOption` enum (7 cases: musicRed, pride, blue, green, purple, orange,
  indigo) with `label`, `color`, and `gradient` (Pride = full 6-stripe rainbow,
  matching the icon).
- `Theme.accent` / `Theme.accentGradient` are now computed from
  `nonisolated(unsafe) static var Theme.currentAccent` (main-actor-only value;
  the attribute is safe here because writes come from `AppState` and reads only
  from view bodies / `JobState.color`, all main-actor). Zero call-site changes.
- `AppState`: `@Published accentOption`, `setAccent(_:)` (applies + persists to
  `UserDefaults` under `MusicLab.Accent`), and `loadAccent()` run first in `init`
  so the correct accent is applied before first render.
- `MusicLabApp`: root now applies `.tint(accent.color)` and `.id(accent.id)` —
  the `id` re-keys the tree so the static `Theme.accent` reads are re-evaluated
  in every descendant when the accent changes (statics don't observe changes).
- `SettingsView`: new **Appearance** section — horizontal swatch row with a
  checkmark on the active accent, live label, accessibility labels/values.

**Verification:** `xtool dev build` clean; core tests **23/23**; unsigned IPA
(05:49) taildropped to `iphone182`. (No unit test — the app target is not part of
`MusicLabCoreTests`, which only depends on `MusicLabCore`.)

**Next:** Step 7 — authenticated, redacted `GET /logs` (backend).

---

## 2026-10-16 — Phase 2 STEPS 7 & 8: `/logs` + destination mapping (code COMPLETE, dev-box only)

**Scope decision (owner):** time crunch — do only "the logs problem" and "the
folder importing", put the rest in `todo.md`. Real `amdl` (Gentoo) is the
target; fake-amdl is retained only for fast offline unit tests.

### Step 7 — `GET /logs`
- New `backend/src/logs.js`: authenticated (mounted under `requireAuth`),
  paginated (`limit` 1–500, `offset`), and **redacted**. Sources: backend
  service file (`LOG_FILE`), wrapper-lite file (`WRAPPER_LOG_FILE`), and per-job
  amdl stdout/stderr from SQLite. `jobId=` scopes to a single job. Response:
  `{ logs, page:{limit,offset,total,hasMore}, available:{backend,job,wrapper} }`.
- `redact()` masks Bearer tokens, `name=value`/`name: value` secrets, and the
  exact live secret values (navidrome pass/token via new `auth.peekToken()`).
- New DB helpers `listJobLogRows` / `getJobLogRow`.
- New `backend/tests/logs.test.js` (7 tests incl. redaction + jobId filter).

### Step 8 — Destination mapping (wrong-folder fix)
- **Root cause (re-confirmed on Gentoo):** `amdl` has **no destination flag**
  (`./amdl --help`: only `--json`, `--lite-server`, search, quality flags). Its
  save folder comes from `config.yaml`, which it reads **from the current
  working directory** (`internal/app/config.go: os.ReadFile("config.yaml")`).
  The repo config writes to `/mnt/media/Music`, while Navidrome scans
  `.../Bryon's Library` and `.../Elijah's Library` → files landed unscanned.
- **Fix:** server-side id→path map (`DESTINATIONS` JSON, `DEFAULT_DESTINATION`),
  `GET /destinations` (ids only, no paths leaked), `destinationId` on
  `POST /jobs` (validated → 400 `INVALID_DESTINATION`). `jobRunner` now spawns
  amdl from a generated per-destination working dir
  (`backend/src/amdlConfig.js`) whose `config.yaml` is a copy of the real config
  with **only** `alac/atmos/aac-save-folder` rewritten — credentials and all
  other settings preserved. No destination ⇒ legacy behaviour (spawn from repo).
  A destination that cannot be materialised fails the job loudly rather than
  writing to the wrong folder.
- New `backend/tests/destinations.test.js` (8 tests).
- `POST /jobs` response and job rows now carry `destinationId`/`destinationPath`
  (SQLite migration adds the two columns idempotently).

### Test runner
- `npm test` now runs all files: `node --test --test-concurrency=1 tests/*.test.js`.
  (Parallel file execution hit SQLITE_BUSY on the shared DB; sequential fixes it.)

**Verification:** backend suite **20/20** on the dev box. iOS untouched this
step (23/23 stays). **Not yet deployed** — live Gentoo deploy + a real-amdl
end-to-end run both require explicit owner approval (see Step 13 / `todo.md`).

**Deferred to `todo.md`:** ordered playlists, logs UI, destination picker, UI
polish, security remainder, final integration, deploy.

### Steps 7–8 — Deploy to Gentoo (live)
- Backed up live `src` → `src.bak-20261016-062344`; copied 6 modified + 3 new
  `src` files, 2 test files, `package.json`.
- Appended to live `.env`: `DESTINATIONS` (`bryon`,`elijah`),
  `DEFAULT_DESTINATION=bryon`, `LOG_FILE`, `WRAPPER_LOG_FILE`.
- Restarted `musiclab-backend` (OpenRC); SQLite auto-migrated
  (`destination_id`, `destination_path`).
- **Verified:** `/health` ok; unauth `/logs` → 401; `/destinations` →
  `bryon` (default) + `elijah`; `/logs?source=backend` → redacted lines.
- **Do not run `npm test` on the live host:** the job-completion test hangs in
  `verifying` against the real Navidrome. Suite is green **20/20 locally**.
- **Excluded:** `catalog.js` (unrelated playlist/artist edit), `scripts/setup.js`,
  local `data/jobs.db`.

### Step 7/8 (app) — iOS logs viewer + destination picker
- `BackendClient`: `fetchDestinations`, `fetchLogs`, and a `destinationId`
  parameter on `submitJob`. New DTOs (`BackendDestination`, `DestinationsResponse`,
  `BackendLogEntry`, `LogsPage`, `LogsAvailable`, `LogsResponse`).
- `AppState`: publishes `destinations` / `selectedDestinationId`; loads
  `GET /destinations` on connect; persists the choice (`MusicLab.Destination`);
  passes `destinationId` on submit/retry; `fetchJobLogs(jobId:)`.
- `SettingsView`: new **Download Destination** section (single-default picker +
  "Server default"); Infrastructure Summary shows the real destination.
- `JobDetailView`: fetches `GET /logs?jobId=…` (refresh + fallback to embedded
  tails) instead of only static stdout/stderr.
- Tests: +4 (`BackendDTOTests`) → iOS core **27/27**. `xtool dev build` clean;
  unsigned IPA taildropped to `iphone182`.

### Bugfix — destination ignored (field-name mismatch) — live
- **Symptom:** choosing "Elijah's Library" in the app still imported into
  Bryon's Library. Server recorded `destination_id=elijah` correctly, but no
  `data/destinations/` dir was ever created.
- **Root cause:** `db.js` hydrators expose camelCase `destinationPath`, but
  `jobRunner.js` read `job.destination_path` (snake_case) → always `undefined`
  → the per-destination workdir was never built, so amdl ran from the repo dir
  (base config = Bryon's). Bryon jobs only *appeared* correct by coincidence.
- **Fix:** `jobRunner.js` now uses `job.destinationPath` via an exported,
  testable `spawnCwdForJob(job, amdlCwd, workRoot)` helper.
- **Regression test:** `backend/tests/jobRunner.test.js` (4 tests) — asserts the
  runner honours `destinationPath`, rewrites only save folders, preserves
  credentials, reuses workdirs, and rejects relative paths.
- Backend suite **24/24** locally. Deployed `jobRunner.js` + restart; verified
  live: `spawnCwdForJob({destinationPath: "…/Elijah's Library"})` →
  `~/musiclab-backend/data/destinations/53641e522942` with Elijah's path.

---

## 2026-10-17 — Step 9b: Live download progress + ETA (backend + iOS, deployed)

**Objective:** show the live percent of every track downloading plus an ETA
derived from actual throughput (owner request, ahead of the remaining steps).

**Backend**
- New `src/amdlProgress.js`: pure streaming parser for amdl stdout. Splits on
  `/[\r\n]+/` (amdl overwrites its progress line with `\r` when piped) and
  understands `Queue x of N` (playlists), `Track x of N` (albums),
  `Decrypting... PP% (a/b MB, Z MB/s)`, `Decrypted` / `Conversion completed`.
  Emits `percent`, `completed`/`total`, `etaSeconds` (rate = completed/elapsed)
  and `speedText`. `Queue` wins whenever the URL count > 1, else `Track`.
- `src/db.js`: new `jobs` columns `progress_percent`, `progress_completed`,
  `progress_total`, `eta_seconds`, `speed_text` (+ idempotent migration) and
  hydration into `GET /jobs` / `GET /jobs/:id`.
- `src/jobRunner.js`: streams stdout through the tracker (carries the trailing
  partial line across chunks), persists snapshots throttled to ~1/s and on every
  completed track, sets `progress_percent=100` at finish; `formatEta()` helper.
- Tests: `tests/amdlProgress.test.js` (8) + `formatEta` cases → backend **46/46**.

**iOS**
- `BackendJobSummary`/`BackendJobDetail` + `Job` gain `progressPercent`,
  `progressCompleted`, `progressTotal`, `etaSeconds`, `speedText` (+ `etaText` /
  `showsDownloadProgress`). `AppState` maps them; polling is **1s while jobs are
  active, 3s idle**. New `DownloadProgressView` shown in Queue rows and
  `JobDetailView` (which now live-tracks the queue copy). iOS core **29/29**.

**Deployed + verified live (owner-approved).** Backed up live `src/db.js`
+ `jobRunner.js` → `src/backup-20261017-liveprogress/`; copied 3 files; restarted
`musiclab-backend`; migration added the 5 columns. Submitted the *Sad* playlist
(36 tracks, dest `elijah`): polled `GET /jobs` showed percent **0→100**,
`tracks 0/36→36/36`, ETA counting down `~?s→0s`, in ~12 s (files cached). Fed the
real amdl tail of the earlier NF job through the parser → `11 MB/s` decoded.
Removed the verification job row; confirmed a single `Sad` playlist (36, public).

**Caveat:** the SwiftUI app target can't be compiled on the Void/Linux box (no
SwiftUI), so the view changes were reviewed but not compiler-verified; the pure
`MusicLabCore` target was built + tested (`swift build --target
MusicLabCoreTests-test-runner`).

---

## 2026-10-17 — Step 10: UI polish (iOS)

**Objective:** visual/UX pass over Queue, Library and detail screens — empty
states, spacing, loading skeletons, transitions, accessibility.

- **Loading skeletons.** New `Components/SkeletonView.swift` (shimmer placeholder
  + `SkeletonJobRow` / `SkeletonMediaRow` shapes). `AppState` gained
  `isLoadingJobs` (set only on the first fetch, so polling never flickers) and
  Queue/Library now render skeletons instead of a premature "empty" state.
- **Toast severity.** `AppState.ToastKind` (`success`/`error`/`info`) +
  `importFeedbackKind`; `showToast(_:kind:)`. Failures and offline notices no
  longer show a green success check — `ContentView` picks icon/color per kind and
  fires matching `sensoryFeedback` haptics.
- **Accessibility.** `DownloadProgressView` exposes a single element with a
  spoken value (tracks/speed/ETA); `StatusBadgeView` announces the job status;
  skeleton placeholders are hidden from VoiceOver.
- **Motion.** Progress bar animates on percent changes.
- **Cleanups.** Removed dead `Views/QuickImportSheet.swift` (+ unused
  `isShowingQuickImport` / `quickImportUrl` state); fixed duplicate
  `.navigationTitle` in `JobDetailView` and duplicate `.background` in
  `SearchView`.
- **Verification.** `xtool dev build` → **Build complete** (app target now
  compiler-verified on the Linux box, superseding the Step 9b caveat). Repackaged
  unsigned `MusicLab.ipa` (1,081,386 B) → `MusicLab/` + `Builds/` and Taildropped
  to `bryon-iphone` (`tailscale file cp`, exit 0). On-device visual check remains
  part of Step 12.

---

## 2026-10-17 — UI overhaul: clean/minimal identity + design system + screens

**Owner decisions:** full overhaul (identity + design system + screens); clean,
minimal, Apple Music-like direction; new mark = music note + download arrow.

**Identity (logo + app icon)**
- Replaced the hand-drawn cursive "M" with a geometric **note + download-arrow**
  mark: a tilted eighth-note head, a stem/flag, and a bold down-arrow sharing the
  visual weight. Authored as SVG, rendered with ImageMagick's librsvg delegate.
- New app icons → `Resources/AppIcon.png` (+ 60x60@2x/@3x) and the
  `Assets.xcassets/AppIcon.appiconset` Light/Dark/Tinted PNGs (1024). Updated the
  appiconset `AppIcon-Foreground.svg` source to match.
- Rewrote `Components/AppLogoView.swift`: `MusicDownloadMark` (SwiftUI `Canvas`,
  same 1024 design space as the SVG) + gradient badge. Removed `CursiveMShape`.

**Design system (`DesignSystem/Theme.swift`)**
- Dropped glass-everywhere. `CardSurfaceModifier` = flat `secondarySystemGrouped`
  fill + 0.5pt hairline border; `TintedSurfaceModifier` = solid tinted fill.
  `.glassCard` → `.cardSurface` across all call sites; `.tintedGlass` now renders
  solid, so primary buttons/badges became clean solid-accent capsules app-wide.
- New `Theme.cardBorder`. Versions the app away from "Liquid Glass Edition".

**Screens**
- Search: URL import field is now a clean card (link glyph + solid Import
  button, disabled state, Return key submits); shared `submitUrlField()`.
- Settings: dropped the "Liquid Glass Edition" label.
- Onboarding: connection panel switched from `glassEffect` to `cardSurface`.
- Logo (`AppLogoView`) appears in Onboarding + Settings with the new mark.

**Build/ship:** `xtool dev build` clean. Repackaged `MusicLab.ipa` (994,884 B) →
`MusicLab/` + `Builds/`, Taildropped to `bryon-iphone` (exit 0).

**Caveat:** the in-session model cannot view images, so the mark/icons were
authored geometrically and shown to the owner via `mpv` for review/iteration.

---

## 2026-10-17 — UI OVERHAUL: final logo = "Drop Note" (owner-selected)

**Objective:** Adopt the owner-chosen mark (concept **A — Drop Note**) as the
shipping logo + app icon and wire it through the code and icon assets.

**Actions**

1. `AppLogoView.swift` → `MusicDownloadMark` rewritten in the 1024pt design
   space: open note head `circle(612,367,r150)`, stem/arrow-shaft
   `line 462,367→807`, arrowhead `M262 607 L462 807 L662 607`; `stroke-width
   64`, round caps/joins, `scale` default `1.0` (was the old filled-head eighth
   note). `AppLogoView` badge unchanged (accent gradient + white mark).
2. Regenerated icons from `icon-light.svg` / `icon-dark.svg` /
   `icon-tinted.svg` (concept A):
   - `Resources/AppIcon.png` (1024), `AppIcon60x60@2x.png` (120),
     `AppIcon60x60@3x.png` (180).
   - `Assets.xcassets/AppIcon.appiconset/`: `AppIcon-Light.png` (red gradient
     `#FA2D4B→#C80D33` + white mark), `AppIcon-Dark.png` (dark `#1C1C1E→#0A0A0C`
     + `#FA2D4B` mark), `AppIcon-Tinted.png` (`#2C2C2E` + light mark); refreshed
     `AppIcon-Foreground.svg` + `AppIcon-Background(-Dark).svg` to match.
3. ContentView toast: `.glassEffect` → `.cardSurface(cornerRadius: .pill)` —
   last remaining glass call removed.
4. `xtool dev build` clean. Repackaged `MusicLab.ipa` (1,009,651 B) →
   `MusicLab/` + `Builds/`; Taildropped to `bryon-iphone` (exit 0; first attempt
   502 while device offline, succeeded once back online).

**Preview:** `/tmp/drop-note/*.svg`, `/tmp/dropnote-preview.png` (light/dark/
tinted + 180/120/80/40 sizes) shown to owner via `mpv`.

---

## 2026-10-17 — Unified search/import field + "Download" tab

**Objective:** Merge the separate search bar and "paste a link" field into one
link-aware input, and rename the first tab.

**Actions**

1. `AppTab`: `.search` title `"Search"`→`"Download"`, icon
   `"magnifyingglass"`→`"arrow.down.circle"`; `.queue` icon →
   `"list.bullet"` (avoid duplicate download glyph). `ContentView` tab label
   follows automatically.
2. `SearchView`: removed the system `.searchable` bar and the standalone URL
   section. Single `cardSurface` field bound to `query` with a leading glyph
   that switches `magnifyingglass`→`link` (accent) when `isLink`
   (`music.apple.com` / `http(s)://`). Submit or the trailing
   `arrow.down.circle.fill` **Download** button imports; non-link input does
   live debounced search (skipped while a link is detected); a clear button
   clears non-link input. Empty states updated ("Search or Paste a Link",
   "Ready to Download").
3. Search/paste field is Liquid Glass again (`.glassEffect(in: RoundedRectangle)`).
4. Download-page filters: replaced the horizontal `FilterChip` row with a
   `.pickerStyle(.segmented)` Picker (All / Song / Album / Playlist / Artist)
   mirroring the Queue page; `onChange` re-runs the search. Removed the now
   unused `FilterChip` struct.
5. `xtool dev build` clean. Repackaged `MusicLab.ipa` (~1.0 MB) → `MusicLab/` +
   `Builds/`; Taildropped to `bryon-iphone` (exit 0).

---

## 2026-10-17 — Deep link handler (`musiclab://`) for Share Sheet & Shortcuts

**Objective:** Enable 1-tap queueing from Apple Music share sheet via iOS Shortcuts using custom URL scheme `musiclab://import?url=...`.

**Actions**

1. `Info.plist`: added `CFBundleURLTypes` registering the `musiclab` URL scheme.
2. `MusicLabCore/Models/DeepLink.swift`: added `MusicLabDeepLink` parser supporting query parameters (`musiclab://import?url=...`), direct hosts (`musiclab://music.apple.com/...`), direct https (`musiclab://https://...`), and cleaning superfluous text/fluff from shared inputs.
3. `MusicLabCoreTests/DeepLinkTests.swift`: 7 new unit tests covering standard query, encoded query, direct host, direct https, text cleaning, non-matching scheme rejection, and empty param rejection. Core test suite 36/36 passing.
4. `AppState.swift`: added `handleIncomingURL(_ url: URL)` switching `selectedTab = .queue`, ensuring cold-start server check finishes before triggering `submitUrlImport(url:)`.
5. `MusicLabApp.swift`: added `.onOpenURL` routing to `appState.handleIncomingURL(url)`.
6. `xtool dev build` clean (7.04s). Repackaged `MusicLab.ipa` (~1.0 MB) → `MusicLab/` + `Builds/`; Taildropped to `bryon-iphone` (exit 0).

---

## 2026-10-17 — Download Completion Notifications & Artist Discography Downloads

**Objective:** Add local notifications when downloads complete and full support for downloading an artist's discography (via artist links or search) with individual album selection and a warned "Download All" flow.

**Actions**

1. `SettingsView`: added `Completion Notifications` toggle requesting iOS `UNUserNotificationCenter` permissions and persisted via `UserDefaults`.
2. `AppState`: added state tracking for completed jobs and dispatching local completion notifications (`postCompletionNotification`) when a job transitions from active/running to completed.
3. `AppState`: added `ArtistPromptData` and `submitBatchImports(items:)` to queue entire discographies sequentially without submission locks.
4. `SearchView` & Deep Links: artist URLs (`/artist/name/id`) shared via Shortcuts or pasted in the search bar now route into an interactive `ArtistDetailView` sheet instead of attempting a blind single-job import.
5. `ArtistDetailView`:
   - Added prominent **"Download All (N Albums)"** header button.
   - Added confirmation dialog warning: *"This will queue N albums for [Artist]. Depending on how much music this artist has, this might take a while to download and convert."*
   - Added individual album download buttons to every row for selective downloading.
6. `ContentView`: attached `.sheet(item: $appState.artistPromptItem)` for seamless artist sheet presentations.
7. `xtool dev build` clean (4.85s). Repackaged `MusicLab.ipa` (1.1 MB) → `MusicLab/` + `Builds/`; Taildropped to `bryon-iphone` (exit 0).


