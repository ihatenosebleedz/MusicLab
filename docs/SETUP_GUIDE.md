# 🛠 MusicLab Self-Hosting & Backend Setup Guide

This guide walks you through setting up the complete MusicLab ecosystem on your self-hosted Linux server (Ubuntu, Debian, Gentoo, Arch, Fedora, etc.).

---

## 🏗 Architecture Overview

The system consists of 4 lightweight components working together on your server:

1. **Navidrome:** Your Subsonic-compatible music streaming server. Watches your music library and indexes new albums immediately.
2. **`amdl`:** The command-line downloader (zhaarey/apple-music-alac-atmos-downloader) that fetches lossless audio and converts it to FLAC/ALAC.
3. **`wrapper-lite`:** Rootless helper service that supplies DRM decryption keys to `amdl`.
4. **`musiclab-backend`:** Node.js Express service that receives jobs from your iPhone, orchestrates `amdl`, tracks live download percentage/speed, generates `.m3u8` playlists, and reports status.

---

## 📋 Prerequisites

- **Linux Server:** Any x86_64 or ARM64 Linux host (Ubuntu/Debian/Arch/Gentoo/Fedora).
- **Node.js:** v22.0.0 or newer (`node -v`).
- **npm:** v10.0.0 or newer.
- **Navidrome:** Installed and running (typically on port 4533).
- **Tailscale (Recommended):** For secure, zero-config access between your iPhone and server away from home without port forwarding.

---

## Step 1: Set Up `amdl` and `wrapper-lite`

1. Create a dedicated folder for the downloader:
   ```bash
   mkdir -p ~/apple-music-downloader && cd ~/apple-music-downloader
   ```

2. Download the pre-built `amdl` CLI binary for your architecture from the [apple-music-alac-atmos-downloader releases](https://github.com/zhaarey/apple-music-alac-atmos-downloader/releases):
   ```bash
   chmod +x ./amdl
   ```

3. Download and start `wrapper-lite` (DRM helper listening on `127.0.0.1:12340`):
   ```bash
   chmod +x ./wrapper-lite
   ./wrapper-lite &
   ```

4. Configure `config.yaml` in `~/apple-music-downloader/config.yaml`:
   ```yaml
   alac-save-folder: /mnt/media/Music
   atmos-save-folder: /mnt/media/Music
   aac-save-folder: /mnt/media/Music
   exit-on-error: true
   flac-conversion: true
   embed-lrc: true
   ```
   *(Note: `musiclab-backend` dynamically steers downloads per-destination, so the save folders here act as fallbacks).*

5. Authenticate `amdl` once with your Apple Music credentials:
   ```bash
   ./amdl
   ```
   Follow the on-screen prompts to log in.

---

## Step 2: Install `musiclab-backend`

1. Clone the MusicLab repository:
   ```bash
   cd ~
   git clone https://github.com/<your-username>/MusicLab.git
   cd MusicLab/backend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Generate a secure random Bearer token:
   ```bash
   npm run generate-token
   ```
   This generates a 64-character secret token saved to `backend/data/token.secret`.

4. Configure your `.env` file:
   ```bash
   cp .env.example .env
   nano .env
   ```

   **Example `.env` configuration:**
   ```env
   PORT=3000
   HOST=0.0.0.0

   TOKEN_FILE=./data/token.secret
   DB_PATH=./data/jobs.db

   # Downloader paths
   AMDL_CWD=/home/nbz/apple-music-downloader
   AMDL_BIN=./amdl
   WRAPPER_LITE_URL=http://127.0.0.1:12340

   # Navidrome configuration
   NAVIDROME_URL=http://127.0.0.1:4533
   NAVIDROME_USER=your_navidrome_username
   NAVIDROME_PASS=your_navidrome_password
   MUSIC_FOLDER=/mnt/media/Music

   # Library Destinations (comma-separated list of destination folders)
   DESTINATIONS=bryon,elijah
   DEFAULT_DESTINATION=bryon

   # Logging
   LOG_FILE=/var/log/musiclab-backend.log
   ```

5. Verify tests:
   ```bash
   npm test
   ```
   *(All test suites should pass).*

6. Test run the server:
   ```bash
   npm start
   ```
   Check health in your browser or curl:
   ```bash
   curl http://localhost:3000/health
   ```
   You should see: `{"status":"ok", ...}`.

---

## Step 3: Run as a Persistent Daemon

### Option A: Using `systemd` (Ubuntu / Debian / Arch / Fedora)

Create `/etc/systemd/system/musiclab-backend.service`:
```ini
[Unit]
Description=MusicLab Backend Service
After=network.target navidrome.service

[Service]
Type=simple
User=your_user
WorkingDirectory=/home/your_user/MusicLab/backend
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now musiclab-backend
```

### Option B: Using `OpenRC` (Gentoo / Alpine)

Create `/etc/init.d/musiclab-backend`:
```sh
#!/sbin/openrc-run

name="musiclab-backend"
description="MusicLab import proxy backend"
directory="/home/your_user/MusicLab/backend"
command="/usr/bin/npm"
command_args="start"
command_user="your_user"
command_background=true
pidfile="/run/musiclab-backend.pid"

depend() {
    need net
    after navidrome
}
```

Enable and start:
```bash
doas rc-update add musiclab-backend default
doas rc-service musiclab-backend start
```

---

## Step 4: Connect the iOS App

1. Sideload `MusicLab.ipa` onto your device (via TrollStore, AltStore, SideStore, etc.).
2. Open **MusicLab** on your iPhone.
3. During Onboarding (or in the **Settings** tab):
   - **Backend URL:** Enter your server's Tailscale or local IP (e.g., `http://100.x.y.z:3000`).
   - **Bearer Token:** Paste the contents of `backend/data/token.secret`.
   - Tap **Test & Connect**. The indicator should turn green: `Online (v1.0.0, amdl ready)`.
4. Choose your preferred default **Download Destination** in Settings.

---

## Step 5: Install the Apple Music Share Shortcut

### Option A: 1-Tap Install (Recommended)
1. Open this link on your iPhone: **[Install "Add to MusicLab" Shortcut](https://www.icloud.com/shortcuts/15de06d0d8034d8c850174ff9e0ebea5)**.
2. Tap **Add Shortcut**.
3. In Apple Music, tap **Share** on any track, album, or playlist, scroll to the bottom, tap **Edit Actions**, and tap **(+)** next to **Add to MusicLab** to pin it to Favorites at the top of your Share Sheet.

### Option B: Manual Creation
1. Open the iOS **Shortcuts** app and tap **(+)**.
2. Name it **Add to MusicLab**.
3. Tap **(i)** at the bottom and switch on **Show in Share Sheet**. Set input to **URLs** and **Text**.
4. Add action: **URL** → `musiclab://import?url=[Shortcut Input]`.
5. Add action: **Open URLs** → passing the URL from the previous step.
6. Pin it to your Favorites in the Share Sheet.

🎉 **You're all set!** Whenever you tap share in Apple Music, it routes straight into your self-hosted Navidrome library!
