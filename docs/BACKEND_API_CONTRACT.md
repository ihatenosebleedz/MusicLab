# BACKEND API CONTRACT & AMD_L SPECIFICATION — Music Lab

> Authoritative contract between the iOS app (`MusicLab`), the Node.js backend (`musiclab-backend`), the downloader CLI (`amdl`), and Navidrome.
> Frozen in STEP 5.

---

## 1. Service Architecture & Networking

- **Host:** Gentoo Linux (`192.168.4.64` LAN, `100.116.177.77` Tailscale, hostname `gentoo`).
- **Runtime:** Node.js v26.3.0 (`npm` 11.16.0).
- **Service Deployment:** `/home/nbz/musiclab-backend`, executed as user `nbz`.
- **Binding:** `0.0.0.0:3000` (accessible over Tailscale and local 192.168.4.x LAN).
- **Public Funnel:** Not exposed on Tailscale Funnel. Guarded by Tailscale network encryption and API Bearer Token.

---

## 2. Authentication & Security

- **Scheme:** HTTP Bearer Authentication.
- **Header:** `Authorization: Bearer <token>`
- **Token Format:** 32+ character high-entropy random string generated on the server (`data/token.secret`).
- **Validation:** Constant-time comparison (`crypto.timingSafeEqual`) to prevent timing side-channel attacks.
- **Protected Endpoints:** All `/jobs`, `/catalog`, and `/history` endpoints require the bearer token.
- **Public Endpoints:** `GET /health` is unauthenticated for readiness probes.
- **Execution Isolation:** No arbitrary shell commands are permitted. The backend accepts only validated Apple Music URLs matching `https://music.apple.com/...`. The command argv is constructed strictly as `['./amdl', '--json', validatedUrl]`.

---

## 3. Endpoints

### 3.1 `GET /health`
Returns the status of the backend and underlying services.

- **Auth:** None
- **Response 200 OK:**
```json
{
  "status": "ok",
  "version": "1.0.0",
  "timestamp": "2026-10-13T21:40:00.000Z",
  "services": {
    "amdl": {
      "path": "/home/nbz/apple-music-downloader/amdl",
      "available": true
    },
    "wrapperLite": {
      "endpoint": "http://127.0.0.1:12340",
      "healthy": true,
      "regions": ["us"]
    },
    "navidrome": {
      "endpoint": "http://127.0.0.1:4533",
      "musicFolder": "/mnt/media/Music",
      "openSubsonic": true
    }
  }
}
```

---

### 3.2 `GET /catalog/search`
Proxies Apple Music catalog searches to `amp-api.music.apple.com` using the backend's auto-refreshed anonymous web token. Eliminates any need for API credentials in the mobile app.

- **Auth:** Required
- **Query Parameters:**
  - `term` (string, required): Search query (e.g., `GNX`).
  - `types` (string, optional, default: `albums,songs`): Comma-separated list (`albums`, `songs`, `playlists`, `artists`).
  - `storefront` (string, optional, default: `us`): 2-letter storefront code.
  - `limit` (integer, optional, default: `20`, max: `50`): Result limit.
- **Response 200 OK:**
```json
{
  "results": {
    "albums": [
      {
        "id": "1781290351",
        "type": "album",
        "title": "GNX",
        "artistName": "Kendrick Lamar",
        "releaseDate": "2024-11-22",
        "artworkUrl": "https://is1-ssl.mzstatic.com/.../600x600bb.jpg",
        "trackCount": 12,
        "appleMusicUrl": "https://music.apple.com/us/album/gnx/1781290351",
        "genre": "Hip-Hop/Rap"
      }
    ],
    "songs": []
  }
}
```

---

### 3.3 `POST /jobs`
Submits a new import job.

- **Auth:** Required
- **Request Body:**
```json
{
  "url": "https://music.apple.com/us/album/gnx/1781290351",
  "name": "Kendrick Lamar — GNX"
}
```
- **Validation:**
  - `url` must parse successfully against `AppleMusicURL` schema (`https://music.apple.com/{storefront}/{type}/...`).
  - If a job for the identical URL is already active (`queued`, `downloading`, `verifying`), the existing job is returned with HTTP 409 Conflict (or existing job status).
- **Response 201 Created:**
```json
{
  "id": "c1f77d8a-81a2-4a87-b9c2-509f6e14a1e9",
  "type": "album",
  "url": "https://music.apple.com/us/album/gnx/1781290351",
  "name": "Kendrick Lamar — GNX",
  "state": "queued",
  "stage": "resolving",
  "progressHint": "Job enqueued",
  "createdAt": "2026-10-13T21:40:00.000Z",
  "updatedAt": "2026-10-13T21:40:00.000Z",
  "addedTracks": []
}
```

---

### 3.4 `GET /jobs`
Lists import jobs.

- **Auth:** Required
- **Query Parameters:**
  - `status` (string, optional): `active`, `completed`, `failed`.
  - `limit` (integer, optional, default: `50`).
- **Response 200 OK:**
```json
{
  "jobs": [
    {
      "id": "c1f77d8a-81a2-4a87-b9c2-509f6e14a1e9",
      "type": "album",
      "url": "https://music.apple.com/us/album/gnx/1781290351",
      "name": "Kendrick Lamar — GNX",
      "state": "verifying",
      "stage": "verifying",
      "progressHint": "Waiting for Navidrome auto-discovery (attempt 2/10)",
      "createdAt": "2026-10-13T21:35:00.000Z",
      "updatedAt": "2026-10-13T21:38:00.000Z",
      "addedTracksCount": 12,
      "navidrome": {
        "verified": false,
        "matches": 0
      }
    }
  ]
}
```

---

### 3.5 `GET /jobs/:id`
Returns full job inspection details.

- **Auth:** Required
- **Response 200 OK:**
```json
{
  "id": "c1f77d8a-81a2-4a87-b9c2-509f6e14a1e9",
  "type": "album",
  "url": "https://music.apple.com/us/album/gnx/1781290351",
  "name": "Kendrick Lamar — GNX",
  "state": "completed",
  "stage": "done",
  "progressHint": "12 tracks downloaded and verified in Navidrome",
  "createdAt": "2026-10-13T21:35:00.000Z",
  "updatedAt": "2026-10-13T21:39:00.000Z",
  "startedAt": "2026-10-13T21:35:02.000Z",
  "finishedAt": "2026-10-13T21:39:00.000Z",
  "exitCode": 0,
  "stdoutTail": "Completed: 12/12\nSuccess",
  "stderrTail": "",
  "addedTracks": [
    {
      "title": "wacced out murals",
      "artist": "Kendrick Lamar",
      "album": "GNX",
      "path": "/mnt/media/Music/Kendrick Lamar/GNX (2024)/01 - wacced out murals.flac"
    }
  ],
  "navidrome": {
    "verified": true,
    "checkedAt": "2026-10-13T21:39:00.000Z",
    "matches": 12
  }
}
```

---

### 3.6 `POST /jobs/:id/cancel`
Cancels an active job.

- **Auth:** Required
- **Behavior:** Sends `SIGTERM` to the process group (`-pgid`), followed by `SIGKILL` after 5 seconds if still active. Updates job state to `cancelled`.
- **Response 200 OK:**
```json
{
  "id": "c1f77d8a-81a2-4a87-b9c2-509f6e14a1e9",
  "state": "cancelled",
  "cancelledAt": "2026-10-13T21:40:00.000Z"
}
```

---

### 3.7 Error Response Format
All errors return a consistent RFC-7807 inspired envelope:
```json
{
  "error": {
    "code": "INVALID_URL",
    "message": "The provided URL is not a valid Apple Music catalog link.",
    "details": "Expected host music.apple.com"
  }
}
```
Standard error codes:
- `UNAUTHORIZED` (401): Missing or invalid Bearer token.
- `INVALID_URL` (400): Malformed or unsupported URL.
- `JOB_NOT_FOUND` (404): Job ID does not exist.
- `JOB_ALREADY_ACTIVE` (409): Identical item currently in download queue.
- `DOWNLOADER_ERROR` (500): `amdl` CLI failed with non-zero exit code.
- `WRAPPER_LITE_OFFLINE` (503): wrapper-lite DRM service is unreachable.

---

## 4. `amdl` Subprocess Execution Contract

### 4.1 Working Directory and Invocation
- **CWD:** `/home/nbz/apple-music-downloader`
- **Binary:** `./amdl`
- **Execution Arguments:**
  ```bash
  ./amdl --json "<apple-music-url>"
  ```
  *(Note: There is no `--url` flag; `<url>` is passed as a positional argument. The `--json` flag causes `amdl` to emit the JSON summary on completion).*

### 4.2 Process Group & Cancellation
- The process is spawned with `{ detached: true }` so it heads its own process group (`pgid = child.pid`).
- To cancel:
  ```javascript
  process.kill(-child.pid, 'SIGTERM');
  ```
  This cleanly terminates `amdl` and any child `ffmpeg` transcode subprocesses.

### 4.3 Output Format Parsing
- **Exit Code 0 (Success):**
  The last non-empty line of `stdout` contains a JSON array of `AddedTrack` objects:
  ```json
  [
    {
      "path": "/mnt/media/Music/Artist/Album/01 Track.flac",
      "artist": "Kendrick Lamar",
      "artist_id": "368183298",
      "album": "GNX",
      "song": "wacced out murals"
    }
  ]
  ```
  *Note: `amdl` emits `"song"`, which maps to track title (`title = track.song || track.title`).*
- **Exit Code != 0 (Failure):**
  `config.yaml` has `exit-on-error: true`. Any failure (e.g. rate limit, unavailable track) exits immediately with code `1`. The backend captures the last 50 lines of `stderr` and `stdout` into `job.stderrTail` and sets `state = failed`.

---

## 5. Navidrome Verification Contract

### 5.1 Verification Principles
- **No Trigger Scans:** Per user requirement, Navidrome auto-discovers library changes in `/mnt/media/Music`. The backend must **never** call scan trigger endpoints.
- **Verification Strategy:**
  1. **Filesystem Check:** Verify `fs.existsSync(track.path)` for every track returned in `AddedTrack[]`.
  2. **OpenSubsonic Polling:** Query Navidrome's OpenSubsonic API:
     ```
     GET /rest/search3.view?query={title}&u={username}&t={token}&s={salt}&v=1.16.1&c=musiclab&f=json
     ```
  3. **Backoff Schedule:** Check at `t = 2s, 4s, 8s, 16s, 32s, 64s, 120s`.
  4. **Timeout:** If tracks are verified on the filesystem but do not appear in OpenSubsonic within 120 seconds, mark `navidrome.verified = false` but `state = completed` with a note `"File present on disk; awaiting Navidrome index cycle"`.

---

## 6. Job State Machine & Persistence

```mermaid
stateDiagram-v2
    [*] --> queued
    queued --> resolving : Subprocess starting
    resolving --> downloading : amdl started
    downloading --> processing : transcoding / flac
    processing --> waiting_for_navidrome : amdl exited 0
    waiting_for_navidrome --> verifying : OpenSubsonic polling
    verifying --> completed : verified in library
    
    resolving --> failed : exit != 0
    downloading --> failed : exit != 0
    processing --> failed : exit != 0
    
    queued --> cancelled : user cancel
    resolving --> cancelled : user cancel
    downloading --> cancelled : user cancel
    
    completed --> [*]
    failed --> [*]
    cancelled --> [*]
```

### 6.1 Database Schema (SQLite: `data/jobs.db`)
```sql
CREATE TABLE IF NOT EXISTS jobs (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    url TEXT NOT NULL,
    name TEXT NOT NULL,
    state TEXT NOT NULL,
    stage TEXT,
    progress_hint TEXT,
    exit_code INTEGER,
    stdout_tail TEXT,
    stderr_tail TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    started_at TEXT,
    finished_at TEXT,
    navidrome_verified INTEGER DEFAULT 0,
    navidrome_checked_at TEXT,
    navidrome_matches INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS job_tracks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id TEXT NOT NULL,
    title TEXT NOT NULL,
    artist TEXT NOT NULL,
    album TEXT NOT NULL,
    path TEXT NOT NULL,
    FOREIGN KEY(job_id) REFERENCES jobs(id) ON DELETE CASCADE
);
```

### 6.2 Restart Recovery
On backend startup:
1. Query `SELECT * FROM jobs WHERE state IN ('queued', 'resolving', 'downloading', 'processing', 'waiting_for_navidrome', 'verifying')`.
2. For jobs in `downloading`/`processing`: check if process still exists via `process.kill(pid, 0)`. If process is gone:
   - Check if files exist at target location.
   - If files exist, transition to `waiting_for_navidrome`.
   - If not, transition to `failed` with error code `SERVER_RESTARTED`.
