# Music Lab Backend (`musiclab-backend`)

Minimal, robust Node.js backend proxying Apple Music catalog requests and managing `amdl` import jobs for the Music Lab iOS application.

---

## 1. Quick Start

### Prerequisites
- Node.js >= 22 (tested on v22.23.2 and v26.3.0)
- npm >= 10

### Setup
```bash
cd backend
npm install
npm run generate-token
```
This generates a high-entropy secret token saved to `backend/data/token.secret`.

### Running Locally
```bash
# Start server
npm start

# Run in watch mode for development
npm run dev
```

### Running Test Suite
```bash
npm test
```
The test suite exercises:
- URL validation & schema parsing for Apple Music links
- Public `/health` readiness & diagnostic endpoint
- Timing-safe Bearer token authentication enforcement
- Job submission, queueing, and execution via fake `amdl` harness
- Process-group cancellation (`SIGTERM`/`SIGKILL`)
- Error envelopes and duplicate request rejections

---

## 2. Configuration (`.env`)

See `.env.example` for full options:

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `PORT` | `3000` | Port to bind |
| `HOST` | `0.0.0.0` | Host binding address |
| `TOKEN_FILE` | `./data/token.secret` | Path to Bearer secret token file |
| `DB_PATH` | `./data/jobs.db` | SQLite database file location |
| `AMDL_CWD` | `/home/nbz/apple-music-downloader` | Working directory for `amdl` CLI |
| `AMDL_BIN` | `./amdl` | Executable path for `amdl` |
| `NAVIDROME_URL` | `http://127.0.0.1:4533` | Navidrome OpenSubsonic base URL |
| `NAVIDROME_USER` | `nbz` | Navidrome OpenSubsonic username |
| `NAVIDROME_PASS` | `""` | Navidrome password (MD5 token salted at runtime) |
| `WRAPPER_LITE_URL` | `http://127.0.0.1:12340` | wrapper-lite DRM helper URL |
| `MUSIC_FOLDER` | `/mnt/media/Music` | Destination music root directory |

---

## 3. Endpoints Overview

- `GET /health` (Public): Service status, dependencies check (`amdl`, `wrapper-lite`, `navidrome`).
- `GET /catalog/search?term=...` (Auth): Proxies search to Apple Music Web API using scraped bearer token.
- `POST /jobs` (Auth): Creates and queues an import job for a validated Apple Music URL.
- `GET /jobs?status=...&limit=...` (Auth): Lists recent import jobs.
- `GET /jobs/:id` (Auth): Detailed status, log tails (`stdoutTail`, `stderrTail`), and track list.
- `POST /jobs/:id/cancel` (Auth): Cancels active job using process group `SIGTERM`/`SIGKILL`.
