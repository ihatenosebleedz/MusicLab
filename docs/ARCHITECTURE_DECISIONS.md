# ARCHITECTURE DECISIONS — Music Lab

> Significant decisions with context, options, choice, rationale, tradeoffs,
> and status (PROVISIONAL / CONFIRMED). Unknowns are marked as unknowns.
>
> **None of these are locked in until STEP 1 is approved by the user.**

---

## D0. Native app + xtool toolchain

- **Context:** Must ship a native iOS app; user chose xtool (Linux-only Xcode
  replacement) on the Void dev box.
- **Options:** (a) SwiftUI + xtool/SwiftPM; (b) SwiftUI + Xcode (unavailable on
  Linux); (c) React Native/Expo (like sibling `yuzic`).
- **Choice:** (a) SwiftUI + xtool.
- **Rationale:** User-stated requirement; xtool 1.21.0 present; Swift 6.4.1
  toolchain present.
- **Tradeoffs:** xtool may lag Xcode features; needs `xtool setup` (Apple auth
  + Darwin SDK) before any build; some APIs may need a "generate-xcode-project"
  fallback for anything xtool can't express.
- **Status:** CONFIRMED (user requirement). **Blocker:** SDK/auth not set up.

---

## D1. Backend language/stack — **DECIDED: Node.js**

- **Context:** Backend runs on Gentoo, wraps the `amdl` CLI, serves the app,
  queries Navidrome.
- **Decision (user, 2026-10-13):** **Node.js**.
- **Rationale:** Least code; matches the prior `amdl-provider` and `yuzic`'s
  `tools/downtify-provider`; trivial child-process/process-group control; no
  build step; runs as an OpenRC service under `nbz`.
- **Status:** CONFIRMED.

---

## D2. Drive `amdl` as-is (no modification)

- **Context:** The downloader is existing infra that must be preserved.
- **Choice:** Backend invokes `./amdl` from its repo root with `--json`, one
  process group per job, `cwd=/home/nbz/apple-music-downloader`; kill the
  process group to cancel (also kills ffmpeg children).
- **Rationale:** STEP 0 confirmed `amdl` has no API; `exit-on-error: true`
  makes it script-friendly; `--json` gives `AddedTrack[]` (real paths).
- **Tradeoffs:** No byte-level progress (only stage ladder); a job holds a
  child process; must ensure only the backend (not the app) ever runs `amdl`.
- **Status:** CONFIRMED as the integration direction (STEP 5 will finalise the
  contract).

---

## D3. No arbitrary shell execution from the API

- **Context:** The API must never become an open command proxy.
- **Choice:** Accept only validated Apple Music URLs / catalog ids; reconstruct
  the `amdl` argv server-side from a fixed allowlist of flags; reject anything
  else.
- **Status:** CONFIRMED (security requirement).

---

## D4. Catalog metadata path — **DECIDED (backend proxy); detail to confirm in STEP 1**

- **Context:** The app needs Apple Music search + album/track metadata. Apple's
  official catalog API needs a developer token (MusicKit key). `amdl` itself
  uses a scraped short-lived **web** token against `amp-api.music.apple.com`,
  and its `--search song|album|artist` subcommand is an **interactive survey**
  (prints a table, reads a selection from stdin) — not directly scriptable.
- **User input (2026-10-13):** the search capability lives in the `amdl`
  binary (`--search song|album|artist`), and downloading a song also fetches
  the **cover image and `.lrc` lyrics as separate sidecar files**.
- **Decision (provisional):** the backend performs catalog **search +
  metadata** by calling the same `amp-api.music.apple.com` web-token endpoint
  that `amdl` uses internally (no Apple secret in the app; token refreshed
  server-side). The app shows results; importing an item runs
  `amdl <apple-music-url>`, which downloads audio **plus the separate cover
  and `.lrc` sidecars**.
- **Open sub-question for STEP 1:** whether to (a) call amp-api directly
  (recommended) or (b) drive `amdl --search` non-interactively by piping a
  selection. (b) is brittle and hard to parse; (a) mirrors `amdl` exactly.
- **UI consequence:** artwork in the app comes from catalog metadata, not from
  the sidecar image files; lyrics sidecars are server-side only unless a later
  step surfaces them.
- **Tradeoffs:** web-token scraping is unofficial and may break → the API must
  degrade gracefully and the backend is a hard dependency for search.
- **Status:** DECIDED direction; exact call path to finalise in STEP 1.

---

## D5. Navidrome verification via OpenSubsonic — **DECIDED (poll only; no scan trigger)**

- **Context:** Completion of `amdl` ≠ visible in Navidrome.
- **Facts:** Navidrome 0.64.2, OpenSubsonic on, port 4533, library at
  `/mnt/media/Music` (where `amdl` writes).
- **User decision (STEP 0):** "It already auto-discovers" — Navidrome picks up
  new files under `/mnt/media/Music` on its own, so the backend must **not**
  trigger scans.
- **Choice:** Backend, after `amdl` reports the file path(s), (1) confirms the
  file exists, (2) polls the OpenSubsonic API (`search3`/`getSong`) until the
  expected track appears, (3) reports verified only on match.
- **To verify in STEP 11:** confirm empirically that a newly written file is
  discovered without a manual/triggered scan, and measure the typical delay.
- **Status:** DECIDED; empirical confirmation pending.

---

## D6. Connectivity — **DECIDED: Tailscale + LAN**

- **Context:** App on iPhone must reach Gentoo; the iPhone is already on the
  tailnet (`iphone182`, active).
- **User decision (STEP 0):** "Tailscale + LAN" — bind `0.0.0.0`, reachable both
  over Tailscale and on `192.168.4.x`; not exposed on the public funnel.
- **Choice (proposed):** Backend listens on `0.0.0.0:<port>`; requests always
  authenticated with a bearer token; TLS optional (Tailscale already encrypts
  transport; LAN traffic is bearer-protected). Do **not** front it with the
  public funnel.
- **Tradeoffs:** LAN exposure means the token is the only guard on the local
  network; keep it long/random and rotate if leaked.
- **Status:** DECIDED (binding); TLS choice to finalise in STEP 1/6.

---

## D7. Authentication — **PROVISIONAL (needs Q3)**

- **Context:** API must authenticate the app; secret must not ship in the app.
- **Choice (proposed):** A single bearer token (or a small token) generated on
  the server, entered by the user into the app once, stored in the iOS
  **Keychain**. Constant-time comparison server-side. Not multi-user.
- **Tradeoffs:** Personal-use only; token rotation is manual; no OAuth.
- **Status:** PROVISIONAL.

---

## D8. Job persistence — PROVISIONAL

- **Proposed states:** `queued → resolving → downloading → processing →
  waiting_for_navidrome → verifying → completed | failed | cancelled`
  (to be reconciled with `amdl`'s real stage signals + the Downtify contract
  prior art; the app only needs a coarse subset).
- **Persistence:** a small embedded store (SQLite or JSON file) on Gentoo so
  jobs survive backend restarts.
- **Status:** CONFIRMED (STEP 5: SQLite `data/jobs.db` with `jobs` and `job_tracks` tables).

---

## D9. No fake progress

- **Choice:** `amdl` exposes no byte counts → the backend reports the real
  stage ladder and file paths only; never invent percentages.
- **Status:** CONFIRMED (brief requirement).

---

## D10. iOS project layout

- **Choice:** xtool SwiftPM project with `MusicLab` app target depending on
  pure-Foundation `MusicLabCore` target. Enables Linux unit testing (`MusicLabCoreTests`)
  via `swift build --target MusicLabCoreTests-test-runner` with 0 warnings.
- **Status:** CONFIRMED (implemented in STEP 3 & 4).

---

## D11. `amdl` CLI invocation & output contract

- **Finding (STEP 5):** `amdl` accepts positional URLs: `./amdl --json <url>`
  (there is no `--url` flag).
- **Format:** Outputs JSON array of `AddedTrack` on the last line of stdout on exit 0.
- **Fields:** `path`, `artist`, `artist_id`, `album`, `song` (`song` maps to track title).
- **Process management:** Spawn with `{ detached: true }` and kill `-pid` (process group) on cancel.
- **Status:** CONFIRMED (empirically verified against `amdl` Go source on Gentoo).

---

## Decision log from STEP 0 questions

- **Q1 — Backend stack:** **Node.js** (DECIDED → D1).
- **Q2 — Backend deployment on Gentoo:** install under
  **`~/musiclab-backend`**, run as user `nbz`; an OpenRC service is OK
  **eventually** (not during automated tests). (DECIDED.)
- **Q3 — API auth:** single **bearer token** generated server-side, entered once
  into the app, stored in the iOS Keychain. (DECIDED → D7.)
- **Q4 — Navidrome scan:** **auto-discovers**; backend polls only, no scan
  trigger. (DECIDED → D5; verify empirically in STEP 11.)
- **Q5 — Network exposure:** **Tailscale + LAN** (`0.0.0.0`); not the public
  funnel. (DECIDED → D6.)
- **Q6 — Catalog metadata:** use `amdl`'s underlying Apple catalog mechanism;
  artwork and `.lrc` are downloaded separately by `amdl`. Exact call path
  (amp-api direct vs. driving `--search`) to confirm in STEP 1. (DECIDED
  direction → D4.)
- **Q7 — Import scope now:** **album + single track + playlist**. (DECIDED.)
- **Q7b — xtool setup:** the developer runs `xtool setup`; the **user types the
  Apple ID password interactively** (never stored). To be done at the start of
  STEP 2, not now. Open detail: whether the Apple ID is a paid Developer
  account or free/SideStore-style signing — **confirm in STEP 2**.
- **Q8 — Git:** **initialise a git repo now** with a `.gitignore`. (DECIDED.)

### Remaining unknowns (non-blocking for STEP 1, resolve as we reach the step)

- Exact `xtool` signing/provisioning account type (free vs. paid) → STEP 2.
- Whether TLS is needed on the API in addition to bearer auth over LAN (D6).
- Empirically confirm Navidrome auto-discovery timing (STEP 11).
- Exact catalog call path for search (STEP 1/4).
