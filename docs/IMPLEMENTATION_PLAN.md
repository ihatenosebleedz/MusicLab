# IMPLEMENTATION PLAN — Music Lab

> Phases and numbered steps, objectives, dependencies, acceptance criteria,
> testing requirements, and status. Refinements are recorded in
> `PROJECT_STATUS.md` and `docs/ENGINEERING_LOG.md`.
>
> Status legend: NOT STARTED · IN PROGRESS · AWAITING APPROVAL ·
> AWAITING USER TEST · BLOCKED · DONE.

| Step | Title | Depends on | Status |
|------|-------|-----------|--------|
| 0 | Repository discovery & environment audit | — | DONE |
| 1 | Architecture & implementation specification | 0 | DONE |
| 2 | Dev environment & minimal iOS app | 1, P1, P2 | DONE |
| 3 | Design system & navigation | 2 | DONE |
| 4 | Apple Music catalog integration | 3 | DONE |
| 5 | Gentoo downloader investigation & API contract | 1 | DONE |
| 6 | Backend API implementation | 5 | DONE |
| 7 | Downloader adapter & real integration | 6 | DONE |
| 8 | iOS ↔ backend integration | 7, 2 | DONE |
| 9 | Import submission workflow | 4, 8 | DONE |
| 10 | Persistent queue & live progress | 9 | DONE |
| 11 | File processing & Navidrome verification | 7, 8 | DONE |
| 12 | Library & history | 11 | DONE |
| 13 | Release discovery | 4 | DONE |
| 14 | UI polish & accessibility | 3–12 | NOT STARTED |
| 15 | Reliability & security audit | all | NOT STARTED |
| 16 | Final end-to-end acceptance | all | NOT STARTED |
| 17 | Release preparation | 16 | NOT STARTED |

---

## STEP 0 — Repository discovery & environment audit

**Objective:** Understand the current project + dev environment without changing
behaviour; discover the real downloader and Navidrome; identify tooling limits.

**Acceptance criteria**
- Current project state documented. ✔
- Tooling limitations identified. ✔
- Unknowns explicitly listed. ✔
- No existing functionality changed. ✔
- Required docs created/initialised. ✔

**Testing:** Manual inspection of generated docs; confirm working tree unchanged
(no code). Evidence gathered read-only from Gentoo.

**Result:** Complete. Repository docs created; environment audited; auth + Darwin SDK installed. All step-0 acceptance criteria met. Approved to proceed to STEP 1.

---

## STEP 1 — Architecture & implementation specification

**Objective:** Concrete, repository-specific plan.

**Deliverables**
- App architecture (SwiftUI/xtool, module boundaries, concurrency).
- Backend architecture wrapping `amdl` (tentatively Node or Python; pending Q1).
- Data flow: catalog search → import → download → verify in Navidrome.
- API request/response models + error model + auth.
- Job persistence & restart recovery.
- Navidrome verification method (OpenSubsonic) incl. scan-delay handling.
- Apple Developer / credential / signing / device prerequisites.
- Unit/integration/manual test definitions per component.

**Acceptance criteria:** Every feature scoped; API + state models documented;
security risks & open questions listed; plan fits existing infra; no
unsupported capability assumed.

**Testing:** Doc review against real `amdl` + Navidrome capabilities.

**Blocked by:** answers to OPEN QUESTIONS (see ARCHITECTURE_DECISIONS).

---

## STEP 2 — Development environment & minimal iOS app

**Objective:** Reproducible native iOS build workflow.

**Tasks:** Run `xtool setup` (auth + SDK); scaffold SwiftPM iOS app
(`xtool new` or hand-rolled); minimal SwiftUI entry point + home screen;
establish build/test commands; document tooling gaps.

**Acceptance criteria:** Project builds via documented workflow (or a concrete
external blocker is named); real SwiftUI `@main` entry; no fake backend claims;
build procedure documented.

**Testing:** `xtool dev build` (or `swift build` cross-target) succeeds; app
installs/launches on device (user test).

**Blocked by:** xtool auth + Darwin SDK (P1/P2).

---

## STEP 3 — Design system & navigation

**Objective:** Visual foundation.

**Tasks:** colour palette + typography; spacing/layout tokens; navigation
structure; Discover/Search/Queue/Library/Settings tab shells; loading/empty/
error/unavailable states; isolated preview data.

**Acceptance criteria:** every primary tab opens; nav works; consistent styling;
states designed; no action falsely claims success.

**Testing:** build (`xtool dev build` succeeded); UI smoke on device (IPA generated and queued via Tailscale to `iphone182`).

**Result:** Complete. Theme, tokens, components (StatusBadge, StageLadder, Card, StateViews), models (CatalogItem, Job, ServerConfig), mock preview data, AppState, 5 primary tabs (Discover, Search, Queue, Library, Settings), detail views (ItemDetail, JobDetail), and QuickImportSheet implemented. Strict Swift 6 concurrency satisfied. Builds cleanly.

---

## STEP 4 — Apple Music catalog integration

**Objective:** Real catalog search + metadata presentation.

**Tasks:** decide catalog path (backend-proxied AMP web token — recommended —
vs. app-held developer token); search endpoint; Artist/Album/Track models;
artwork, titles, release dates, tracklists; pagination; error/empty/rate-limit
handling; Apple Music URL parsing; unit tests for decoding/URL/errors.

**Acceptance criteria:** real catalog data; correct decoding; graceful invalid
URLs; tests cover success + failures; **no API secret in the app**.

**Testing:** Unit tests in `MusicLabCoreTests` passed (8 URL parser tests + 2 decoder tests); `xtool dev build` clean build in 3.88s; IPA generated (626K).

**Result:** Complete. `MusicLabCore` module created with `AppleMusicURL` parser and `AppleMusicClient`/`AppleMusicParsing`. AMP API models implemented. Web token scraping (zero developer secret) implemented. 10 unit tests passing on Linux. `AppState` and `SearchView` integrated with live search and validated URL import.

---

## STEP 5 — Gentoo downloader investigation & API contract

**Objective:** Determine the safest way to drive `amdl`.

**Findings already established in STEP 0** (see PROJECT_STATUS §4.2):
`amdl` is a CLI; `--json` emits `AddedTrack[]`; album/song/playlist/artist/
station URLs supported; writes to `/mnt/media/Music`; `exit-on-error: true`;
requires running `wrapper-lite`.

**Tasks:** finalise the validated job schema; define job ids + status
responses; cancellation/retry based on real capability (process-group kill
possible: `amdl` spawns ffmpeg children); persistence; auth; network exposure;
deployment + rollback doc.

**Acceptance criteria:** interface matches real `amdl`; unsupported ops named;
security/ops documented; **contract approved before implementation**.

**Testing:** Empirical inspection of `amdl` Go source on Gentoo (`run.go`, `app.go`, `config.yaml`); `wrapper-lite` `/status` probe; OpenSubsonic ping probe; contract documented in `docs/BACKEND_API_CONTRACT.md`.

**Result:** Complete. `docs/BACKEND_API_CONTRACT.md` created with frozen REST specification, process-group management, `AddedTrack` schema mapping (`song` -> `title`), Navidrome polling algorithm, and SQLite persistence schema.

---

## STEP 6 — Backend API implementation

**Objective:** Smallest reliable API the app needs.

**Tasks:** implement approved contract; auth; validation; job submission;
lookup + history; persistence; structured errors; health/readiness;
automated tests with a **fake `amdl`**; config/startup docs.

**Constraints:** no connection to the real music collection; no changes to the
real Gentoo service yet; no arbitrary shell execution.

**Acceptance criteria:** contract fully implemented; timing-safe Bearer token auth; Apple Music URL validation; job queue with process-group detachment and cancellation; SQLite persistence with restart recovery; structured RFC-7807 error responses; automated test suite passing with fake `amdl`.

**Testing:** 6 automated tests in `tests/api.test.js` exercising URL parser, public `/health`, timing-safe auth, job submission & fake `amdl` execution, cancellation endpoint, and invalid URL rejection. 100% tests passing (`6/6 passed`).

**Result:** Complete. `backend/` scaffolded with Express + better-sqlite3. Config, SQLite schema, auth middleware, URL parser, job runner with process-group kill, Navidrome OpenSubsonic verification adapter, and catalog proxy implemented and tested.

---

## STEP 7 — Downloader adapter & real integration

**Objective:** Connect backend to real `amdl`.

**Tasks:** adapter translating jobs → `amdl` invocation (cwd = downloader dir,
`--json`, process-group kill on cancel); parse stage ladder; capture real
`AddedTrack` paths; map failures; dedupe; deploy + rollback. Manual,
explicitly-requested test only; no bulk downloads.

**Acceptance criteria:** adapter matches `amdl`; failures visible; no fabricated
progress; downloader untouched/working; live integration deployed on Gentoo.

**Testing:**
- Backend deployed to `nbz@192.168.4.64` (`gentoo`) at `~/musiclab-backend`.
- Native `node:sqlite` engine verified without node-gyp native compilation mismatch.
- Service installed under OpenRC (`/etc/init.d/musiclab-backend`) on port `3001` (port 3000 in use by `next-server`).
- Live health check returns 200 OK with `amdl` available, `wrapper-lite` healthy (`regions: ["us"]`), and `navidrome` OpenSubsonic ping OK.
- Catalog search verified over HTTP against live backend via scraped AMP web token.
- Accessible directly on LAN (`192.168.4.64:3001`) and over Tailscale (`100.116.177.77:3001`).

**Result:** Complete. Downloader adapter deployed live to Gentoo as a managed OpenRC daemon with active connection to `amdl` in `~/apple-music-downloader`, `wrapper-lite`, and Navidrome.

---

## STEP 8 — iOS ↔ backend integration

**Objective:** Talk to a test backend.

**Tasks:** networking module; models; auth; secure credential storage
(Keychain); connection test; error/offline handling; tests against a fake
server; **no blocking the main thread**; no hardcoded host/credentials.

**Acceptance criteria:** asynchronous networking actor in Swift; typed DTOs matching backend contract; configuration supports Tailscale and LAN addresses with token auth; non-blocking actor calls; automated tests pass; IPA builds and deploys cleanly.

**Testing:**
- Implemented `BackendDTOs.swift` and `BackendClient.swift` actor.
- Added 4 unit tests in `BackendDTOTests.swift` covering DTO decoding, health models, and job request encoding. 14/14 tests passing.
- Wired `AppState` to check server connection upon launch and test button, refresh live jobs from backend, and forward queue submissions and cancellations.
- Verified build with `xtool dev build` (0 errors, 0 warnings, build in 2.65s).
- Packaged `MusicLab.ipa` (696 KB) and sent to `iphone182` via Taildrop (`tailscale file cp`).

**Result:** Complete. iOS networking client implemented and fully integrated into AppState, SettingsView, and QueueView. Updated IPA deployed to device.

---

## STEP 9 — Import submission workflow

**Objective:** Submit a real import from the app.

**Tasks:** album detail screen; track selection; confirmation; submit; reflect
true server response; dedupe double-taps; conflict handling; tests.

---

## STEP 10 — Persistent queue & live progress

**Objective:** Live monitoring.

**Tasks:** queue screen; persistent jobs from backend; sync; live updates
(WebSocket/SSE if supported) + polling fallback; accurate status; job detail;
retry/cancel only where supported; reconnect after resume; tests.

**Note:** `amdl` exposes no byte-level progress → report the **stage ladder**
only (resolving → downloading → processing → done). No fake percentages.

---

## STEP 11 — File processing & Navidrome verification

**Objective:** Verify tracks really land in Navidrome.

**Tasks:** confirm AMDL post-processing done; check files at configured paths;
**OpenSubsonic** query (e.g. `search3`/`getSong`); allow scan latency; match
stable ids / normalized metadata; handle partial/deferred; report accurately.
Pending Q4 (scan trigger vs. automatic discovery).

---

## STEP 12 — Library & history

**Objective:** Useful view of existing/recent music.

**Tasks:** recent history; success/fail rows; library lookup via
Subsonic/OpenSubsonic; duplicate hints where reliable; open-in-client (deep
link / web URL); empty/unavailable states; tests.

---

## STEP 13 — Release discovery

**Objective:** Make new music easy to find.

**Tasks:** followed artists; release metadata; recent releases + dates; refresh
+ cache; handle unreleased/region gaps; **opt-in** local notifications; no
auto-download on release.

---

## STEP 14 — UI polish & accessibility

**Objective:** Production-quality feel.

**Tasks:** typography/spacing; artwork presentation; restrained animation +
haptics; review all states; multiple iPhone sizes; safe areas + keyboard;
a11y labels + Dynamic Type; contrast; remove dead UI; full build/UI tests.

---

## STEP 15 — Reliability & security audit

**Objective:** Failure-scenario testing.

**Test matrix:** backend down; server reboot mid-job; bad auth; expired
credentials; network loss on submit; duplicate submit; downloader failure;
partial download; processing failure; scan delay; missing tracks; bad catalog
URL; malformed responses; resume-reconnect; unauthorized API access; path
traversal outside configured dirs. Fix criticals; document the rest.

---

## STEP 16 — Final end-to-end acceptance

**Objective:** Full journey on device + real server with one small, authorized
test import; observe queue, download, Navidrome discovery, final status.

---

## STEP 17 — Release preparation

**Objective:** Reproducible personal release.

**Tasks:** final build; install/deploy docs; backend deploy + rollback; secret
management; troubleshooting; known limitations; final test report; signing/
distribution notes. No public distribution without permission.
