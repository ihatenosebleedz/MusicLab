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
| 2 | Dev environment & minimal iOS app | 1, P1, P2 | IN PROGRESS |
| 3 | Design system & navigation | 2 | NOT STARTED |
| 4 | Apple Music catalog integration | 3 | NOT STARTED |
| 5 | Gentoo downloader investigation & API contract | 1 | NOT STARTED |
| 6 | Backend API implementation | 5 | NOT STARTED |
| 7 | Downloader adapter & real integration | 6 | NOT STARTED |
| 8 | iOS ↔ backend integration | 7, 2 | NOT STARTED |
| 9 | Import submission workflow | 4, 8 | NOT STARTED |
| 10 | Persistent queue & live progress | 9 | NOT STARTED |
| 11 | File processing & Navidrome verification | 7, 8 | NOT STARTED |
| 12 | Library & history | 11 | NOT STARTED |
| 13 | Release discovery | 4 | NOT STARTED |
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

**Testing:** build; UI smoke on device (user test).

---

## STEP 4 — Apple Music catalog integration

**Objective:** Real catalog search + metadata presentation.

**Tasks:** decide catalog path (backend-proxied AMP web token — recommended —
vs. app-held developer token); search endpoint; Artist/Album/Track models;
artwork, titles, release dates, tracklists; pagination; error/empty/rate-limit
handling; Apple Music URL parsing; unit tests for decoding/URL/errors.

**Acceptance criteria:** real catalog data; correct decoding; graceful invalid
URLs; tests cover success + failures; **no API secret in the app**.

**Note:** Apple Music's public web token is short-lived and scraped; the
backend already needs this capability to mirror the (now-deleted) provider
prototype. Pending Q6.

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

---

## STEP 6 — Backend API implementation

**Objective:** Smallest reliable API the app needs.

**Tasks:** implement approved contract; auth; validation; job submission;
lookup + history; persistence; structured errors; health/readiness;
automated tests with a **fake `amdl`**; config/startup docs.

**Constraints:** no connection to the real music collection; no changes to the
real Gentoo service yet; no arbitrary shell execution.

---

## STEP 7 — Downloader adapter & real integration

**Objective:** Connect backend to real `amdl`.

**Tasks:** adapter translating jobs → `amdl` invocation (cwd = downloader dir,
`--json`, process-group kill on cancel); parse stage ladder; capture real
`AddedTrack` paths; map failures; dedupe; deploy + rollback. Manual,
explicitly-requested test only; no bulk downloads.

**Acceptance criteria:** adapter matches `amdl`; failures visible; no fabricated
progress; downloader untouched/working.

---

## STEP 8 — iOS ↔ backend integration

**Objective:** Talk to a test backend.

**Tasks:** networking module; models; auth; secure credential storage
(Keychain); connection test; error/offline handling; tests against a fake
server; **no blocking the main thread**; no hardcoded host/credentials.

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
