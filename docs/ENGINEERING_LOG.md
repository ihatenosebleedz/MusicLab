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
