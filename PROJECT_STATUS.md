# PROJECT STATUS — Music Lab

> Authoritative record of project state. Updated at the end of every numbered step.
> This file must never contain credentials, tokens, passwords, keys, or Apple ID values.

**Last updated:** 2026-10-13 (STEP 1 COMPLETE → STEP 2 IN PROGRESS)
**Current phase:** STEP 2 — Development environment & minimal iOS app
**Next step (not started):** STEP 3 — Design system & navigation (pending explicit STEP 2 approval)

---

## 1. Project overview

"Music Lab" is a native iOS (SwiftUI) app for personal use that:

1. Searches the Apple Music catalog (song / album / artist).
2. Displays release metadata and artwork.
3. Submits import jobs to an authenticated backend running on the existing
   Gentoo Linux host.
4. The backend drives the existing Apple Music downloader (`amdl`).
5. The app monitors job progress.
6. The backend verifies the resulting files appear in Navidrome.
7. The app reports verified completion; the user plays the result in Navidrome
   or another compatible client.

The app orchestrates existing infrastructure; it must not reimplement the
downloader or Navidrome.

---

## 2. Current objective (STEP 0)

Document the current repository and development environment, discover the real
downloader/Navidrome setup, identify tooling limitations and prerequisites, and
raise the questions that must be answered before architecture work begins.

---

## 3. Repository and project structure

- Working directory: `/home/nbz/Projects/apple-music-ios-downloader`
- **Empty** at STEP 0 start. **Not a git repository** (no `.git`).
- No app, backend, or downloader integration exists here yet.
- Only files present after STEP 0 are the documentation created in this step.

```
apple-music-ios-downloader/
├── PROJECT_STATUS.md              # this file
└── docs/
    ├── IMPLEMENTATION_PLAN.md
    ├── ENGINEERING_LOG.md
    ├── ARCHITECTURE_DECISIONS.md
    └── TESTING.md
```

---

## 3a. Environment audit (Void Linux dev box)

| Item | Finding |
| --- | --- |
| Host OS | Void Linux, kernel 6.18.50_1, x86_64 |
| Working dir | `/home/nbz/Projects/apple-music-ios-downloader` (empty) |
| Git | Not a repository (no `.git`) |
| xtool | `/home/nbz/.local/bin/xtool`, built from source (fix #337, `main`@81a2845) — version reports `unversioned`; backup `xtool-1.21.0.bak` present |
| xtool Darwin Swift SDK | **INSTALLED** (`xtool sdk status` → installed; iOS 27.1, macOS 27.0) |
| xtool Apple auth | **Logged in** (`xtool auth status` → bryon.neeley30@gmail.com, team T6XW4ZAFQ5) |
| Swift toolchain | **6.4.1 installed** at `~/.local/share/swift/6.4.1/usr/bin` (on PATH via `.bashrc`) |
| `swift`/`swiftc` | Present under the toolchain path above; not on the default
non-interactive PATH (must prepend `~/.local/share/swift/6.4.1/usr/bin`) |
| Darwin/iOS SDK | **Not installed** (needed by xtool to build) |
| clang/cmake/python3/node/npm/go/rustc | present |
| Physical device check | `xtool devices` hangs waiting for a device → deferred; user will plug iPhone in for later steps |

### xtool capabilities observed (v1.21.0)

- `xtool setup` = `xtool auth && xtool sdk` (authenticate + install Darwin SDK).
- `xtool new <name>` creates a SwiftPM-based iOS project (can `--skip-setup`).
- `xtool dev build|run` builds/runs via SwiftPM; `xtool dev generate-xcode-project`.
- `xtool devices`, `install`, `launch`, `uninstall` manage physical devices
  (USB or network). `install` accepts an `.ipa`.
- No `xcodebuild`, no Apple Xcode on this Linux host.

**Prerequisite/blocker:** `xtool setup` (Apple ID auth + Darwin Swift SDK
install) has NOT been run. This is required before STEP 2 can build anything.

---

## 3. Known prerequisites & blockers

| # | Prerequisite | Status | Impact |
|---|--------------|--------|--------|
| P1 | `xtool` Apple ID auth | DONE (logged in; TLS cert issue worked around with XTL_DISABLE_TLS_VALIDATION=1 for interactive login) | Blocks SDK install → blocks builds |
| P2 | Darwin Swift SDK install (`xtool sdk install`) | DONE (from Xcode_27.1_Release_Candidate.xip) | Blocks iOS compilation |
| P3 | Physical iPhone for on-device testing | Reported available (on Tailscale as `iphone182`) | Needed for manual tests (steps 2/3/9/10/14/16) |
| P4 | Backend stack/language decision | RESOLVED: Node.js | — |
| P5 | Backend deployment target on Gentoo | RESOLVED: `~/musiclab-backend`, user `nbz`, OpenRC eventually | — |
| P6 | Navidrome auto-scan behaviour | RESOLVED: user states auto-discovery; verify empirically in STEP 11 | — |
| P7 | API auth token strategy | RESOLVED: single bearer token → iOS Keychain | — |

---

## 4. Discovered infrastructure (from read-only inspection)

### 4.1 Gentoo host (the "server")

- **Reachable** at `192.168.4.64` (LAN) and Tailscale `100.116.177.77`
  (hostname `gentoo`). SSH port 22 open.
- **SSH access works key-based, non-interactively, as `nbz`.** No password was
  needed, supplied, or stored. (User also offered a password; it was NOT used
  and is NOT recorded here.)
- Hardware: Lenovo ThinkPad T480, Intel i7-8650U. Gentoo (OpenRC). Kernel
  6.18.48-gentoo-dist-bin.
- Tailscale: funnel enabled → **https://gentoo.tail29a9cb.ts.net**.
  Nodes include `gentoo` (100.116.177.77), **`iphone182`** (100.112.66.66,
  active — the user's iPhone is on the tailnet), and `voidlinux`
  (100.78.57.69).
- Docker installed (29.5.2) but the current user cannot access the socket
  without elevation.

### 4.2 Existing downloader (`amdl`)

- Location: `/home/nbz/apple-music-downloader` (= `~/apple-music-downloader`).
- Upstream: `github.com/zhaarey/apple-music-alac-atmos-downloader`.
- A Go program: source under `internal/` + `cmd/`, prebuilt binary `./amdl`
  (~21 MB). Entry: `main.go` → `internal/app`.
- **It is a CLI, not a service. There is NO built-in HTTP API.**
- Invocation (verified from source `internal/app/run.go` + live `--help`):
  `./amdl [options] [url1 url2 ...]`, run from the repo root (so `config.yaml`
  is read from CWD).
  - `--json` prints a JSON array of `AddedTrack` at the **end** (on success).
  - `--search [album|song|artist] <query>` (interactive survey; not scriptable).
  - `--atmos`, `--aac`, `--select`, `--all-album`, `--debug`,
    `--save-m3u8-playlist`, `--lite-server`, `--alac-max`, `--atmos-max`,
    `--aac-type`, `--mv-audio-type`, `--mv-max`.
- Supported URL kinds (regexes in `internal/app/url.go`): album, song,
  music-video, playlist, station, artist (ids: numeric for album/song/artist,
  `pl.…` playlists, `ra.…` stations).
- `AddedTrack` JSON shape (from `internal/app/app.go`):
  `{ "path", "artist", "artist_id", "album", "song" }`.
- Success summary line: `[✔] Completed: X/Y | [⚠] Warnings: W | [✖] Errors: Z`;
  per-item lines `Track N of M:`, `Queue N of M:`.
- Requires the **`wrapper-lite`** helper running locally (DRM key server):
  `internal/app/config.go` reads `lite-server: "http://127.0.0.1:12340"`.
  `wrapper-lite` provides `/status /m3u8 /key /lyrics /webplayback /license`
  and needs an Apple ID login (already configured + running on the server;
  credentials NOT recorded and NOT reused by us).

Key `config.yaml` values observed (secrets excluded):
- `exit-on-error: true`  ← good for automation (no interactive retry loop).
- `alac-save-folder: /mnt/media/Music` (atmos/aac also `/mnt/media/Music`) →
  **AMDL writes directly into the Navidrome music folder. No move step.**
- `convert-after-download: true`, `convert-format: "flac"`.
- `storefront` placeholder text present but code falls back to `us` if not
  2 chars.
- `authorization-token` and `media-user-token` are present in the real config
  (values NOT read/recorded).

Repo note: working tree shows deleted docs (`README.md`, `README-CN.md`,
`PROXY-SETUP.md`) — pre-existing, not caused by us.

### 4.3 Navidrome

- Running on **Gentoo**, pid on TCP **4533**.
- Version **0.64.2**, OpenSubsonic enabled (confirmed via `/rest/ping`).
- Binary `/home/nbz/.local/opt/navidrome/navidrome`; OpenRC service
  `/etc/init.d/navidrome`.
- Data folder `/home/nbz/.local/share/navidrome`; config
  `/home/nbz/.config/navidrome/navidrome.toml`.
- **Music folder: `/mnt/media/Music`** — real library, ~1554 entries.
- `BaseUrl = https://gentoo.tail29a9cb.ts.net` (Tailscale funnel).
- Config also has Last.fm + ListenBrainz settings (values NOT recorded).
- No `Scanner.*` keys set in the config → scan schedule is Navidrome default
  (needs confirmation; see open question Q4).

### 4.4 Related prior art on the Void box (reference only, not dependencies)

- `~/Projects/yuzic` — a shipped React Native (Expo) Subsonic client. It
  already integrates a downloader via the "Downtify provider" wire contract
  (5 endpoints) and includes a reference Node provider
  `tools/downtify-provider/` (yt-dlp-backed) plus docs describing how the app
  detects completion (job row *disappears* → app triggers a media-server
  rescan). Useful prior art for the backend wire contract and Navidrome
  rescan behaviour.
- `~/Projects/maybe-make-a-ios-navidrome-player` — a SwiftUI + SwiftPM
  Subsonic/Navidrome **client** ("Coda", `NaviCore`) with its own tests.
  Its build scripts target macOS/Xcode/SideStore, **not xtool**, so it is not
  a build-workflow template — but `NaviCore` is prior art for a Subsonic
  client and Keychain usage.
- `~/Projects/apple-music-linux` — a Tauri Apple Music client (unrelated to
  backend integration).
- A Node `amdl-provider` prototype briefly existed at
  `~/Projects/amdl-provider`. **The user deleted it during STEP 0** (confirmed:
  directory no longer exists). Design will be done fresh.

---

## 5. Completed steps

- **STEP 0** — Repository discovery and environment audit. **DONE**.

## 6. Active step

- **STEP 1** — Architecture & implementation specification. **DONE**.
- **STEP 2** — Development environment & minimal iOS app. **IN PROGRESS**.

## 7. Steps awaiting user approval

- STEP 2 (minimal app build/launch validation).

## 8. Steps awaiting user physical testing

- None yet.

## 9. Pending prerequisites

- P1/P2 above (xtool auth + Darwin SDK) — to be done at the start of STEP 2;
  the user will type the Apple ID password interactively.
- Git repo still to be initialised (agreed; do at start of STEP 1).
- All STEP 0 questions answered (see §10 and `docs/ARCHITECTURE_DECISIONS.md`).

## 10. Architecture and important design decisions (provisional)

**Resolved in STEP 0 Q&A (2026-10-13):**
- Backend = **Node.js** service on Gentoo, deployed under `~/musiclab-backend`
  as user `nbz` (OpenRC service eventually).
- Backend wraps the existing `amdl` binary (no modification to `amdl`).
- Catalog **search + metadata** proxied by the backend via Apple's `amp-api`
  web-token mechanism that `amdl` uses (no Apple secret in the app). `amdl`
  downloads audio plus separate cover/`.lrc` sidecars.
- Navidrome **auto-discovers**; verification **polls** OpenSubsonic (no scan
  trigger).
- Connectivity: bind `0.0.0.0`, **Tailscale + LAN**, not the public funnel.
- Auth: single **bearer token** → stored in iOS **Keychain**.
- Import scope: **album + track + playlist**.
- Git: initialise a repo in the project dir (do at start of STEP 1).

**Still provisional (STEP 1):** module boundaries, exact job-state machine, job
persistence store, exact catalog call path, TLS detail.

(Full rationale in `docs/ARCHITECTURE_DECISIONS.md`.)

---

## 11. Commands executed in this step (evidence)

- Local: `pwd`, `ls -la`, `git status` (not a repo), `uname -a`,
  `xtool --version`, `xtool {setup,auth,sdk,new,dev,install,launch,devices} --help`,
  `xtool sdk status` (Installed), `xtool auth status` (Logged in),
  `swift --version` (6.4.1), `swift sdk list`.
- Gentoo (read-only over SSH, key auth): `ls ~`, `ls ~/apple-music-downloader`,
  `find`, `cat config.yaml.example`, `cat main.go`, `sed internal/app/{run,url,config,app}.go`,
  `git -C ~/apple-music-downloader remote -v` + `log`, `./amdl --help`,
  `cat ~/.config/navidrome/navidrome.toml`, `cat /etc/init.d/navidrome`,
  `ss -tlnp`, `curl 127.0.0.1:4533/rest/ping`, `ls /mnt/media/Music`,
  `tailscale status`, `ps`.

## 12. Build and test results

- No project code exists yet → no builds/tests run.
- Local tooling check: Swift toolchain OK; **xtool SDK absent** → iOS build not
  yet possible.

## 13. Known bugs and limitations

- xtool cannot build until `xtool setup` completes (auth + SDK).
- `xtool devices` blocks waiting for a device (`--wait` default) — use
  `--no-wait` in scripts.
- `swift`/`xtool` need the Swift toolchain on PATH; non-interactive shells do
  not source `.bashrc`, so PATH must be set explicitly in scripts/CI.

## 14. Blockers and causes

- **STEP 2 blocker:** RESOLVED (auth + SDK installed). Next: STEP 1 or STEP 2 as per plan (step 0 awaiting approval).
- **STEP 1 blocker:** stack/deployment/Navidrome-scan/auth decisions (open
  questions).

## 15. Files changed in latest step

Created:
- `PROJECT_STATUS.md`
- `docs/IMPLEMENTATION_PLAN.md`
- `docs/ENGINEERING_LOG.md`
- `docs/ARCHITECTURE_DECISIONS.md`
- `docs/TESTING.md`

(No code, no deletion, no modification of existing files.)

## 16. Security considerations

- No credentials/tokens/keys/Apple ID recorded in any doc.
- Gentoo inspected **read-only**; no packages installed, no services changed,
  no downloads started, no files written on Gentoo.
- `amdl` config token values were deliberately not read/copied.
- Planned model keeps all secrets server-side; app stores only user-entered
  server URL + API token in iOS Keychain.

## 17. Exact point at which work stopped

After writing the five documentation files and this report. No implementation
of any kind has begun. Waiting for STEP 0 approval.

## 17a. Next planned action

On approval: begin **STEP 1 — Architecture and implementation specification**
(no app code), producing repository-specific architecture, API/state models,
and addressing the open questions.

## 17. Resumption instruction for a future OpenCode session

1. Read this file, then `docs/IMPLEMENTATION_PLAN.md`, recent
   `docs/ENGINEERING_LOG.md`, and `docs/ARCHITECTURE_DECISIONS.md`.
2. Review STEP 1 specification and approve to proceed to STEP 2.
2. Verify the working tree matches §15 (empty repo + docs only).
3. Do **not** advance past the last approved step. Resume only the authorized
   step, following the approval protocol in the project brief.
