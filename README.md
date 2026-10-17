# MusicLab

> **A native iOS client and self-hosted backend pipeline to download songs, albums, and playlists from Apple Music straight into your personal Navidrome library with a single tap from the iOS Share Sheet.**

<p align="center">
  <img src="docs/assets/AppIcon-Rounded.png" width="128" height="128" alt="MusicLab App Icon">
</p>

<p align="center">
  <a href="#features"><img src="https://img.shields.io/badge/iOS-16.0%2B-FA2D4B?logo=apple" alt="iOS 16+"></a>
  <a href="#building-on-linux-no-mac-needed"><img src="https://img.shields.io/badge/Built_on-Linux_via_xtool-blue?logo=linux" alt="Linux xtool"></a>
  <a href="#backend-setup"><img src="https://img.shields.io/badge/Backend-Node.js_22%2B-339933?logo=node.js" alt="Node.js 22+"></a>
  <a href="#backend-setup"><img src="https://img.shields.io/badge/Server-Navidrome_Ready-00A4DC?logo=airplay" alt="Navidrome"></a>
</p>

---

## Demo Workflow

<p align="center">
  <img src="docs/assets/demo.gif" width="300" alt="MusicLab Demo Workflow">
</p>

```
[Apple Music]  ──(Share)──>  [iOS Shortcut]  ──(musiclab://)──>  [MusicLab App]
                                                                        │
                                                                        ▼
[Navidrome Library]  <───  [amdl / FLAC Converter]  <───  [MusicLab Backend]
```

1. **Browse in Apple Music:** Find any track, album, or playlist.
2. **Tap Share → "Add to MusicLab":** Directly from the native iOS Share Sheet.
3. **Watch It Rip:** MusicLab opens to the live Queue with real-time download percentage, throughput speed (MB/s), and ETA.
4. **Instant Stream:** The track lands in your artist/album folders and appears in your Navidrome library immediately.

---

## Features

- **Native iOS Share Sheet Integration:** Share directly from Apple Music using a lightweight iOS Shortcut deep link (`musiclab://import?url=...`). No manual copy-pasting required.
- **Real-Time Download Tracking:** Parses downloader stdout live to provide track numbers (`Track x of N`), decryption percent, live throughput, and ETA countdown.
- **Smart Ordered Playlists:** Automatically resolves public Apple Music playlists, downloads catalog songs into proper artist/album directories, and writes an order-preserving `.m3u8` playlist for Navidrome.
- **Multi-Library Destination Steering:** Switch between library targets (e.g. `Bryon's Library`, `Elijah's Library`) directly inside app Settings or per import.
- **Sleek SwiftUI Design System:** Dark-mode native interface with custom accent color picker (Apple Music Red, Purple, Cyan, Mint, Orange, Pride), card surfaces, and tactile haptics.
- **Built 100% on Linux:** No Mac, Xcode, or Apple Developer hardware needed to develop or build. Compiled using Swift Package Manager and `xtool`.

---

## Quick Start

### 1. Set Up the Backend
The backend runs on your server or home-lab host alongside Navidrome:
```bash
git clone https://github.com/ihatenosebleedz/MusicLab.git
cd MusicLab/backend
npm install
npm run generate-token
cp .env.example .env
# Edit .env with your paths, then:
npm start
```
**Detailed guide:** See the [Self-Hosting Setup Guide](docs/SETUP_GUIDE.md) for step-by-step instructions (systemd/OpenRC services, `amdl` CLI, DRM helpers, and Navidrome integration).

### 2. Install the iOS App
1. Download the latest `MusicLab.ipa` from [GitHub Releases](https://github.com/ihatenosebleedz/MusicLab/releases).
2. Sideload the IPA onto your iPhone using **TrollStore**, **AltStore**, **SideStore**, or **LiveContainer**.
3. Launch MusicLab, enter your backend URL (e.g. `http://100.x.y.z:3000` via Tailscale/LAN) and the secret token.

### 3. Install the iOS Share Sheet Shortcut (1-Tap Install)

<p align="left">
  <a href="https://www.icloud.com/shortcuts/15de06d0d8034d8c850174ff9e0ebea5">
    <img src="https://img.shields.io/badge/iOS_Shortcut-Add_to_MusicLab-FA2D4B?style=for-the-badge&logo=shortcuts&logoColor=white" alt="Add to Shortcuts">
  </a>
</p>

1. Tap **[Add to MusicLab Shortcut](https://www.icloud.com/shortcuts/15de06d0d8034d8c850174ff9e0ebea5)** on your iPhone to install it in one tap.
2. Open **Apple Music**, tap **Share** on any track, album, or playlist.
3. Scroll down in the Share Sheet, tap **Edit Actions**, and tap **(+)** next to **Add to MusicLab** to pin it to your Favorites right at the top!

---

## 🛠 Architecture

```mermaid
flowchart TD
    subgraph iOS ["iOS Device"]
        AM["Apple Music"] -->|Share Sheet| SC["Add to MusicLab Shortcut"]
        SC -->|musiclab://import?url=...| APP["MusicLab App (SwiftUI)"]
    end

    subgraph Server ["Linux Server / Tailscale"]
        APP -->|"POST /jobs (Bearer Token)"| API["MusicLab Backend (Node.js/Express)"]
        API -->|"Job Runner & Progress Parser"| AMDL["amdl (CLI Downloader)"]
        AMDL -->|"DRM Decryption"| WRP["wrapper-lite DRM Service"]
        AMDL -->|"Lossless Audio (FLAC/ALAC)"| LIB["Music Library (/mnt/media/Music)"]
        API -->|"Write .m3u8"| LIB
        LIB -->|"Auto File-Watch Scan"| NAV["Navidrome Server"]
    end
```

---

## Building the iOS App on Linux (No Mac Needed!)

MusicLab is engineered to build natively on Linux using `xtool`:

```bash
# Ensure swift and xtool are installed
cd MusicLab

# Run tests
swift build --target MusicLabCoreTests-test-runner -Xlinker --allow-shlib-undefined
.build/debug/MusicLabCoreTests-test-runner

# Build the .app bundle
xtool dev build

# Package unsigned IPA
mkdir -p /tmp/payload/Payload
cp -R xtool/MusicLab.app /tmp/payload/Payload/
(cd /tmp/payload && zip -r MusicLab.ipa Payload)
```

---

## Security & Privacy

- **Zero Cloud Intermediaries:** All communication is directly between your personal iPhone and your self-hosted backend over your local LAN or secure Tailscale network.
- **Timing-Safe Auth:** The backend enforces constant-time Bearer token verification.
- **Sanitized Logging:** Per-job stdout/stderr logs are automatically redacted for sensitive tokens before being viewed in the app.

---

## License

This project is licensed under the [MIT License](LICENSE).
Apple Music is a trademark of Apple Inc. MusicLab is an independent open-source tool for personal home-lab media server integration.
