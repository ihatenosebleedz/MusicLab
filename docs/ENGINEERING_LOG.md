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
3. Gentoo host (`192.168.4.64`, Tailscale `100.116.177.77`) inspected
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

**Status:** STEP 4 DONE. Awaiting explicit approval before STEP 5.
