/**
 * jobRunner.js — amdl subprocess lifecycle, process group cancellation, and job queue.
 */

import { spawn } from 'child_process';
import { existsSync, writeFileSync, mkdirSync } from 'fs';
import { dirname, join } from 'path';
import { config } from './config.js';
import { updateJob, insertTracks, getActiveJobs } from './db.js';
import { verifyTracks } from './navidrome.js';
import { buildDestinationCwd } from './amdlConfig.js';
import { parseAppleMusicUrl } from './urlParser.js';
import { fetchPlaylistTracks, songUrl } from './appleMusic.js';
import { playlistFilePath, buildPlaylistM3U8 } from './playlistFile.js';
import { createProgressTracker } from './amdlProgress.js';

/** Format a seconds count as "45s", "2m 10s" or "1h 2m". */
export function formatEta(seconds) {
  if (seconds == null || !Number.isFinite(seconds) || seconds < 0) return null;
  const s = Math.round(seconds);
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  const rem = s % 60;
  if (m < 60) return rem ? `${m}m ${rem}s` : `${m}m`;
  const h = Math.floor(m / 60);
  return `${h}h ${m % 60}m`;
}

/** Human progress line for the queue UI / logs. */
function progressHintFor(snapshot) {
  if (snapshot.total && snapshot.total > 0) {
    const current = Math.min(snapshot.total, snapshot.completed + (snapshot.downloading ? 1 : 0));
    let hint = `Downloading track ${Math.max(1, current)} of ${snapshot.total}`;
    if (snapshot.speedText) hint += ` • ${snapshot.speedText}`;
    const eta = formatEta(snapshot.etaSeconds);
    if (eta) hint += ` • ~${eta} left`;
    return hint;
  }
  if (snapshot.speedText) return `Downloading • ${snapshot.speedText}`;
  return 'Downloading tracks from Apple Music';
}

/** Parent directory for per-destination amdl config dirs. */
function destinationWorkRoot() {
  return join(dirname(config.dbPath), 'destinations');
}

/**
 * Choose the amdl working directory for a job. Jobs with a destination run from
 * a generated dir whose config points at that library; others use the repo dir.
 * NOTE: the DB hydrator exposes camelCase fields (`destinationPath`), so read
 * that — not the snake_case DB column. Exported for regression testing.
 */
export function spawnCwdForJob(job, amdlCwd, workRoot = destinationWorkRoot()) {
  if (!job || !job.destinationPath) return amdlCwd;
  return buildDestinationCwd(amdlCwd, job.destinationPath, workRoot);
}

/**
 * Expand a catalog playlist job into the ordered list of per-song download
 * URLs. amdl's `ripSong` (unlike `ripPlaylist`) writes each track into its own
 * artist/album folder with the song's real album metadata, which is exactly the
 * layout MusicLab wants. `ripPlaylist` would instead flatten every track into a
 * single "<PlaylistName>" album.
 *
 * Returns null when the job is not an expandable catalog playlist (caller then
 * falls back to legacy amdl playlist mode). Exported for regression testing.
 *
 * @returns {Promise<{ name: string, songUrls: string[] } | null>}
 */
export async function resolvePlaylistSongs(job, options = {}) {
  if (!job || job.type !== 'playlist') return null;

  const parsed = parseAppleMusicUrl(job.url);
  if (!parsed.valid || parsed.type !== 'playlist') return null;

  const { name, tracks } = await fetchPlaylistTracks(parsed.storefront, parsed.id, options);
  if (!tracks.length) return null;

  return {
    name,
    songUrls: tracks.map((t) => songUrl(parsed.storefront, t.id))
  };
}

// Map of jobId -> childProcess
const activeProcesses = new Map();

// Work queue
const jobQueue = [];
let isProcessing = false;

export function enqueueJob(jobId, amdlBin = config.amdl.bin, amdlCwd = config.amdl.cwd) {
  jobQueue.push({ jobId, amdlBin, amdlCwd });
  processNextJob();
}

export function cancelJob(jobId) {
  const child = activeProcesses.get(jobId);
  if (child) {
    try {
      // Terminate process group cleanly
      process.kill(-child.pid, 'SIGTERM');
      setTimeout(() => {
        try {
          process.kill(-child.pid, 'SIGKILL');
        } catch {}
      }, 5000);
    } catch (e) {
      console.warn(`[jobRunner] Error sending SIGTERM to job ${jobId}:`, e.message);
    }
  }

  // Remove from queue if not started yet
  const idx = jobQueue.findIndex(item => item.jobId === jobId);
  if (idx !== -1) {
    jobQueue.splice(idx, 1);
  }

  updateJob(jobId, {
    state: 'cancelled',
    stage: 'cancelled',
    progress_hint: 'Job cancelled by user',
    finished_at: new Date().toISOString()
  });
}

async function processNextJob() {
  if (isProcessing || jobQueue.length === 0) return;
  isProcessing = true;
  const { jobId, amdlBin, amdlCwd } = jobQueue.shift();

  try {
    await runJob(jobId, amdlBin, amdlCwd);
  } catch (err) {
    console.error(`[jobRunner] Error running job ${jobId}:`, err);
  } finally {
    isProcessing = false;
    processNextJob();
  }
}

async function runJob(jobId, amdlBin, amdlCwd) {
  const { getJob } = await import('./db.js');
  const job = getJob(jobId);
  if (!job || job.state === 'cancelled') return;

  const startedAt = new Date().toISOString();
  updateJob(jobId, {
    state: 'resolving',
    stage: 'resolving',
    progress_hint: 'Resolving metadata with amdl',
    started_at: startedAt
  });

  // Check if amdlBin exists; if not, check resolved path or fail
  let binPath = amdlBin;
  if (!existsSync(binPath) && existsSync(`${amdlCwd}/${binPath}`)) {
    binPath = `${amdlCwd}/${binPath}`;
  }

  if (!existsSync(binPath)) {
    updateJob(jobId, {
      state: 'failed',
      stage: 'failed',
      progress_hint: `Downloader executable not found: ${binPath}`,
      exit_code: 1,
      stderr_tail: `Binary not found at ${binPath}`,
      finished_at: new Date().toISOString()
    });
    return;
  }

  // Steer amdl's save folder for this import. amdl reads config.yaml from its
  // cwd and has no --dest flag, so a job with a destination runs from a
  // generated dir whose config points at the destination library.
  let spawnCwd;
  try {
    spawnCwd = spawnCwdForJob(job, amdlCwd);
  } catch (err) {
    updateJob(jobId, {
      state: 'failed',
      stage: 'failed',
      progress_hint: `Destination config error: ${err.message}`,
      exit_code: 1,
      stderr_tail: err.message,
      finished_at: new Date().toISOString()
    });
    return;
  }

  // Playlist jobs are expanded to per-song downloads so each track lands in its
  // own artist/album folder with normal tags. If the track list cannot be read
  // (e.g. a personal library playlist), fall back to amdl's playlist mode.
  const amdlArgs = ['--json'];
  let playlistName = null;
  let expectedTotal = null;
  if (job.type === 'playlist') {
    updateJob(jobId, {
      state: 'resolving',
      stage: 'resolving',
      progress_hint: 'Resolving playlist track list from Apple Music'
    });
    try {
      const resolved = await resolvePlaylistSongs(job);
      if (resolved) {
        amdlArgs.push(...resolved.songUrls);
        playlistName = resolved.name;
        expectedTotal = resolved.songUrls.length;
        updateJob(jobId, {
          progress_hint: `Downloading ${resolved.songUrls.length} playlist track(s) individually`,
          progress_total: expectedTotal,
          progress_completed: 0,
          progress_percent: 0
        });
      } else {
        console.warn(`[jobRunner] Could not expand playlist for job ${jobId}; using amdl playlist mode`);
        amdlArgs.push(job.url);
      }
    } catch (err) {
      console.warn(`[jobRunner] Playlist expansion failed for job ${jobId}: ${err.message}; using amdl playlist mode`);
      amdlArgs.push(job.url);
    }
  } else {
    amdlArgs.push(job.url);
  }

  // The resolve above is async; a cancel may have landed while it ran.
  const afterResolve = getJob(jobId);
  if (!afterResolve || afterResolve.state === 'cancelled') return;

  return new Promise((resolve) => {
    let stdoutBuffer = '';
    let stderrBuffer = '';

    const tracker = createProgressTracker({ expectedTotal });
    let pending = ''; // incomplete stdout line carried across chunks
    let lastProgressWrite = 0;
    let lastCompleted = 0;

    function persistProgress() {
      const snap = tracker.snapshot();
      const nowMs = Date.now();
      // Throttle DB writes to ~1/s, but always flush when a song completes.
      if (nowMs - lastProgressWrite < 900 && snap.completed === lastCompleted) {
        return;
      }
      lastProgressWrite = nowMs;
      lastCompleted = snap.completed;
      updateJob(jobId, {
        state: 'downloading',
        stage: 'downloading',
        progress_hint: progressHintFor(snap),
        progress_percent: snap.percent,
        progress_completed: snap.completed,
        progress_total: snap.total,
        eta_seconds: snap.etaSeconds,
        speed_text: snap.speedText
      });
    }

    // Spawn amdl detached to create its own process group
    const child = spawn(binPath, amdlArgs, {
      cwd: spawnCwd,
      detached: true,
      env: { ...process.env, PATH: process.env.PATH }
    });

    activeProcesses.set(jobId, child);

    child.stdout.on('data', (chunk) => {
      const str = chunk.toString();
      stdoutBuffer += str;

      // amdl overwrites its progress line with '\r'; buffer the trailing
      // (incomplete) segment so tokens split across chunks still parse.
      const combined = pending + str;
      const parts = combined.split(/[\r\n]/);
      pending = parts.pop();
      const complete = parts.join('\n');

      if (tracker.feed(complete)) {
        persistProgress();
      }
    });

    child.stderr.on('data', (chunk) => {
      stderrBuffer += chunk.toString();
    });

    child.on('error', (err) => {
      activeProcesses.delete(jobId);
      updateJob(jobId, {
        state: 'failed',
        stage: 'failed',
        progress_hint: `Failed to execute amdl: ${err.message}`,
        exit_code: 1,
        stderr_tail: err.message,
        finished_at: new Date().toISOString()
      });
      resolve();
    });

    child.on('close', async (code) => {
      activeProcesses.delete(jobId);
      const finishedAt = new Date().toISOString();

      // Tail logs (last 50 lines)
      const stdoutLines = stdoutBuffer.trim().split('\n');
      const stderrLines = stderrBuffer.trim().split('\n');
      const stdoutTail = stdoutLines.slice(-50).join('\n');
      const stderrTail = stderrLines.slice(-50).join('\n');

      if (code !== 0) {
        const current = getJob(jobId);
        if (current?.state === 'cancelled') {
          return resolve();
        }

        updateJob(jobId, {
          state: 'failed',
          stage: 'failed',
          progress_hint: `amdl process failed with exit code ${code}`,
          exit_code: code,
          stdout_tail: stdoutTail,
          stderr_tail: stderrTail,
          finished_at: finishedAt
        });
        return resolve();
      }

      // amdl exit 0: parse AddedTrack[] from stdout
      let addedTracks = [];
      try {
        // Last non-empty line or find JSON array in stdout
        for (let i = stdoutLines.length - 1; i >= 0; i--) {
          const line = stdoutLines[i].trim();
          if (line.startsWith('[') && line.endsWith(']')) {
            const rawTracks = JSON.parse(line);
            addedTracks = rawTracks.map(t => ({
              title: t.song || t.title || 'Unknown Title',
              artist: t.artist || 'Unknown Artist',
              album: t.album || 'Unknown Album',
              path: t.path || ''
            }));
            break;
          }
        }
      } catch (err) {
        console.warn(`[jobRunner] Could not parse json from stdout: ${err.message}`);
      }

      if (addedTracks.length > 0) {
        insertTracks(jobId, addedTracks);

        // Generate the ordered .m3u8 playlist file INSIDE the destination
        // library. Navidrome only imports M3U files found under a library path,
        // so writing to the global music folder (the old behaviour) made the
        // playlist invisible.
        if (job.type === 'playlist') {
          try {
            const libraryDir = job.destinationPath || config.navidrome.musicFolder;
            const playlistPath = playlistFilePath(
              libraryDir,
              playlistName || job.name || `Playlist_${jobId.slice(0, 8)}`
            );
            mkdirSync(dirname(playlistPath), { recursive: true });
            writeFileSync(
              playlistPath,
              buildPlaylistM3U8(playlistName || job.name, addedTracks),
              'utf8'
            );
            console.log(`[jobRunner] Created playlist file at ${playlistPath} with ${addedTracks.length} tracks`);
          } catch (pErr) {
            console.warn(`[jobRunner] Failed to write playlist file: ${pErr.message}`);
          }
        }
      }

      updateJob(jobId, {
        state: 'waiting_for_navidrome',
        stage: 'verifying',
        progress_hint: `Downloaded ${addedTracks.length} track(s). Verifying in Navidrome...`,
        progress_percent: 100,
        progress_completed: addedTracks.length || null,
        progress_total: addedTracks.length || null,
        eta_seconds: 0,
        exit_code: 0,
        stdout_tail: stdoutTail,
        stderr_tail: stderrTail
      });

      // Verification phase
      const verification = await verifyTracks(addedTracks, (status) => {
        updateJob(jobId, {
          state: 'verifying',
          stage: status.stage,
          progress_hint: status.progressHint
        });
      });

      updateJob(jobId, {
        state: 'completed',
        stage: 'done',
        progress_hint: verification.verified
          ? `${addedTracks.length} tracks downloaded and verified in Navidrome`
          : `${addedTracks.length} tracks downloaded; awaiting Navidrome index cycle`,
        finished_at: new Date().toISOString(),
        navidrome_verified: verification.verified ? 1 : 0,
        navidrome_checked_at: new Date().toISOString(),
        navidrome_matches: verification.matches
      });

      resolve();
    });
  });
}

/**
 * Handle recovery on server restart
 */
export function recoverActiveJobs() {
  const activeJobs = getActiveJobs();
  for (const job of activeJobs) {
    updateJob(job.id, {
      state: 'failed',
      stage: 'failed',
      progress_hint: 'Process interrupted by server restart',
      finished_at: new Date().toISOString()
    });
  }
}
