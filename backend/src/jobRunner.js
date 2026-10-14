/**
 * jobRunner.js — amdl subprocess lifecycle, process group cancellation, and job queue.
 */

import { spawn } from 'child_process';
import { existsSync } from 'fs';
import { config } from './config.js';
import { updateJob, insertTracks, getActiveJobs } from './db.js';
import { verifyTracks } from './navidrome.js';

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

  return new Promise((resolve) => {
    let stdoutBuffer = '';
    let stderrBuffer = '';

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
      return resolve();
    }

    // Spawn amdl detached to create its own process group
    const child = spawn(binPath, ['--json', job.url], {
      cwd: amdlCwd,
      detached: true,
      env: { ...process.env, PATH: process.env.PATH }
    });

    activeProcesses.set(jobId, child);

    child.stdout.on('data', (chunk) => {
      const str = chunk.toString();
      stdoutBuffer += str;
      // Simple stage heuristics if amdl emits downloading/transcoding logs
      if (str.toLowerCase().includes('download') || str.toLowerCase().includes('track')) {
        updateJob(jobId, {
          state: 'downloading',
          stage: 'downloading',
          progress_hint: 'Downloading tracks from Apple Music'
        });
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
      }

      updateJob(jobId, {
        state: 'waiting_for_navidrome',
        stage: 'verifying',
        progress_hint: `Downloaded ${addedTracks.length} track(s). Verifying in Navidrome...`,
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
