# TESTING — Music Lab

> How to run each test class, what needs the real Gentoo server, what needs a
> physical iPhone, and what is safe to run against mocks.
>
> This file is kept in sync with actual project state. At STEP 0 there is no
> code yet, so most sections describe the intended strategy.

---

## 0. Environments

| Env | What it is | Notes |
| --- | --- | --- |
| Dev box | Void Linux, `/home/nbz/Projects/apple-music-ios-downloader` | xtool + Swift 6.4.1 toolchain |
| Device | User's iPhone (`iphone182` on Tailscale) | Required for on-device UX tests |
| Real server | Gentoo `192.168.4.64` / `100.116.177.77` (`gentoo`) | Runs `amdl` + Navidrome 0.64.2; **live library** |

### PATH note
`swift`/`xtool` require the Swift toolchain on PATH. Non-interactive shells do
not source `.bashrc`, so scripts must prepend:

```
export PATH="$HOME/.local/share/swift/6.4.1/usr/bin:$HOME/.local/bin:$PATH"
```

---

## 1. iOS app tests

### 1.1 Compile / build (safe, no server)
- `swift build` (core module) — Linux.
- `xtool dev build` — produces an installable app (once `xtool setup` is done).
- `xtool dev generate-xcode-project` — fallback if a feature needs Xcode.

**Blocks until:** Darwin Swift SDK installed (`xtool sdk install`) + auth.

### 1.2 Unit tests (core module)
- Platform-agnostic core (`MusicLabCore`: models, AppleMusicURL parser, AppleMusicModels decoder, artwork URL generator) tested directly on Linux.
- Execution command:
  ```bash
  export PATH="$HOME/.local/share/swift/6.4.1/usr/bin:$HOME/.local/bin:$PATH"
  cd MusicLab && swift build --target MusicLabCoreTests-test-runner -Xlinker --allow-shlib-undefined && .build/out/Products/Debug-linux-x86_64/MusicLabCoreTests-test-runner
  ```
- Coverage:
  - `AppleMusicURLTests`: Valid album URLs, albums without slug, songs within album (`?i=...`), playlist URLs, artist URLs, invalid hosts, unsupported resource types, malformed URLs (8 tests).
  - `AppleMusicDecoderTests`: Search response JSON decoding, album with track relationships, track explicit tags/durations, artwork URL formatting (2 tests).
  - Result: 10/10 passed in 0.003s.

### 0..n Physical-device tests (require iPhone)
- Install + launch (`xtool install` / `xtool launch`).
- Layout, safe areas, Dynamic Type, haptics, animations.
- End-to-end import against the real backend (see §3). Requires explicit user
  consent; no bulk downloads.

---

## 1.5 Backend unit/integration tests (safe, mock)

- Job submission happy path + validation failures (missing ids, bad URLs).
- Unauthenticated requests rejected; invalid tokens rejected.
- Duplicate submission refused.
- **Fake `amdl` executable** (a script that emits canned stage lines +
  `AddedTrack[]`) → verify adapter parsing, stage mapping, cancel (process-group
  kill), and failure mapping.
- Navidrome verification logic against a **fake OpenSubsonic** responder:
  found / not-found-yet → retry → found, partial import, API error.
- **These are mock tests and must never be reported as real integration tests.**

---

## 1. Tests that require the real Gentoo server

- Catalog search against live Apple Music (via backend token scrape).
- Running `amdl` for a real, user-approved, single small import.
- Navidrome discovery/verification against the live library.
- Restart-recovery of the backend service.

**Rule:** never run destructive or bulk operations against the real library
without explicit permission. Never download music during automated tests.

---

## 2. Tests that require a physical iPhone

- Install/launch via xtool.
- Animations, layout, safe areas, Dynamic Type, haptics.
- End-to-end: search → import → queue → verified.
- Reconnect after backgrounding/resume.

---

## 2. Backend API tests (planned)

- Contract tests for every endpoint (request/response/error shapes).
- Auth tests (missing/invalid token → 401).
- Validation tests (malformed JSON, missing fields, bad URL → 400).
- Job lifecycle + restart recovery.
- Fake `amdl` integration (no real download).
- Never run against the real music collection in CI.

---

## 3. Integration test policy

- **Mocks are allowed** for automated tests, but a passing mock test must
  **never** be reported as a real-world integration test.
- Destructive tests against the real library require explicit permission and a
  small, named target.
- Verification tests must use a **small, explicitly selected** test request,
  never a bulk download.

---

## 4. Manual test procedures (to be filled in as steps land)

Each step will add a numbered procedure here: device/machine, preconditions,
steps, expected result, and what to send back on failure (output/error/
screenshot). Until then this section is a placeholder.

### STEP 2 (when reached) — install & launch minimal app
1. Plug in the iPhone (or ensure it is reachable over Tailscale).
2. `xtool devices --no-wait` to confirm visibility.
3. `xtool dev run` (or build + `xtool install`).
4. Expected: app launches to the minimal home screen.
5. On failure, report the full stderr and any on-device alert text.

---

## 5. Documentation checks

- Confirm `PROJECT_STATUS.md` matches reality (working tree, step, blockers)
  at the start of every session and at the end of every step.
- Reconcile any disagreement between docs and the repo before continuing.

## 6. STEP 1 concrete test matrix

### Backend (Node.js)
- Unit: job state machine transitions; amdl stdout JSON parsing (valid/invalid/missing); error mapping on non-zero exit; auth middleware (missing/wrong token).
- Integration: fake amdl emits AddedTrack[] and exits 0; fake amdl exits non-zero with stderr; Navidrome polling mocks (not found → found → timeout); cancel kills process group.

### iOS (SwiftUI + xtool)
- Unit (Core): Codable models (Job/Track/SearchResult); API client request building, 401 handling, network errors; Keychain token storage (mocked where needed).
- UI smoke: tabs render; search validation; queue shows stages; settings token entry.

### End-to-end (manual, later)
- Real: search → submit album/track/playlist → job completes → tracks appear in Navidrome (polling only). Verify no scan triggered.
