/**
 * amdlProgress.js — parse amdl's stdout into live download progress.
 *
 * amdl emits (see apple-music-downloader internal/app):
 *   - "Queue 15 of 18: " then "Song->Neon Trees"   (overall playlist position)
 *   - "Track 3 of 12: songs"                        (per-album position)
 *   - "Decrypting...  74%  (36/49 MB, 11 MB/s)"     (per-song bytes + speed)
 *   - "[4s] Decrypted" / "Conversion completed ..."
 *
 * On a TTY the Decrypting line is overwritten with '\r'; when piped (our case)
 * the chunks arrive with embedded '\r' bytes, so we split tokens on /[\r\n]/.
 *
 * Playlist imports run one amdl URL per song, so `Queue x of N` (N > 1) is the
 * right unit. Album/song imports run a single URL (`Queue 1 of 1`) and expose
 * their per-track position via `Track x of N` — we fall back to that.
 *
 * The trackers are pure (no I/O) so they are unit-testable; jobRunner decides
 * when to persist snapshots to the DB.
 */

const QUEUE_RE = /Queue\s+(\d+)\s+of\s+(\d+)/i;
const TRACK_RE = /Track\s+(\d+)\s+of\s+(\d+)/i;
const DECRYPT_PCT_RE = /Decrypting\.{0,3}\s*(\d+)\s*%/i;
const SPEED_RE = /([\d.]+)\s*(kB|KB|MB|GB|kiB|KiB|MiB|GiB)\s*\/\s*s/;
const DECRYPTED_RE = /\bDecrypted\b/i;
const CONVERSION_DONE_RE = /Conversion completed/i;

/**
 * Create a stateful progress tracker.
 *
 * @param {object} [opts]
 * @param {number|null} [opts.expectedTotal] Known total song count (playlist
 *   expansion), used before amdl prints its own "Queue x of N".
 * @param {() => number} [opts.now] Clock (ms) — injectable for tests.
 */
export function createProgressTracker(opts = {}) {
  const now = opts.now || (() => Date.now());
  const startedAt = now();

  let queueTotal = Number.isFinite(opts.expectedTotal) ? opts.expectedTotal : null;
  let queueIndex = null;
  let queueFinished = false;

  let trackTotal = null;
  let trackIndex = null;
  let trackFinished = false;

  let fraction = 0; // 0..1 progress within the current unit
  let speedText = null;
  let reachedDecrypting = false;

  let sps = null; // smoothed seconds per unit
  let lastUnitAt = startedAt;

  // `Queue x of N` wins whenever there is more than one URL (playlists);
  // otherwise fall back to the per-album `Track x of N`.
  function mode() {
    if (queueTotal && queueTotal > 1) return 'queue';
    if (trackTotal && trackTotal > 1) return 'track';
    return 'queue';
  }

  function unit() {
    if (mode() === 'track') {
      return { index: trackIndex, total: trackTotal, finished: trackFinished };
    }
    return { index: queueIndex, total: queueTotal, finished: queueFinished };
  }

  function completedCount() {
    const { index, finished } = unit();
    if (index == null) return finished ? 1 : 0;
    const base = finished ? index : index - 1;
    return Math.max(0, base);
  }

  function activeTotal() {
    const { total } = unit();
    return total && total > 0 ? total : null;
  }

  function noteCompletion() {
    if (mode() === 'track') {
      if (trackFinished) return;
      trackFinished = true;
    } else {
      if (queueFinished) return;
      queueFinished = true;
    }
    const t = now();
    const dur = (t - lastUnitAt) / 1000;
    if (dur > 0) sps = sps == null ? dur : 0.4 * dur + 0.6 * sps;
    lastUnitAt = t;
  }

  function snapshot() {
    const done = completedCount();
    const total = activeTotal();
    const overall = done + (unit().finished ? 0 : fraction);

    let percent = null;
    if (total && total > 0) {
      percent = Math.max(0, Math.min(100, (overall / total) * 100));
      percent = Math.round(percent * 10) / 10;
    }

    let etaSeconds = null;
    if (total && total > 0 && done > 0) {
      const elapsed = (now() - startedAt) / 1000;
      const rate = elapsed > 0 ? done / elapsed : 0;
      if (overall >= total) etaSeconds = 0;
      else if (rate > 0) etaSeconds = Math.max(0, Math.round((total - overall) / rate));
    }

    return {
      percent,
      completed: done,
      total,
      etaSeconds,
      speedText,
      downloading: reachedDecrypting || done > 0,
      mode: mode(),
      secondsPerUnit: sps == null ? null : Math.round(sps * 10) / 10
    };
  }

  function setSpeed(seg) {
    const s = seg.match(SPEED_RE);
    if (s) speedText = `${s[1]} ${s[2]}/s`;
  }

  return {
    /** Feed one stdout chunk; returns true if any progress signal was seen. */
    feed(chunk) {
      if (!chunk) return false;
      const text = chunk.toString();
      let changed = false;

      for (const seg of text.split(/[\r\n]+/)) {
        if (!seg) continue;

        let m;
        if ((m = seg.match(QUEUE_RE))) {
          const idx = parseInt(m[1], 10);
          const n = parseInt(m[2], 10);
          if (Number.isFinite(n) && n > 0 && queueTotal == null) queueTotal = n;
          if (Number.isFinite(idx) && (queueIndex == null || idx > queueIndex)) {
            if (queueIndex != null) noteCompletion();
            queueIndex = idx;
            queueFinished = false;
            fraction = 0;
            lastUnitAt = now();
          }
          changed = true;
          continue;
        }

        if ((m = seg.match(TRACK_RE))) {
          const idx = parseInt(m[1], 10);
          const n = parseInt(m[2], 10);
          if (Number.isFinite(n) && n > 0) trackTotal = n;
          if (Number.isFinite(idx) && (trackIndex == null || idx > trackIndex)) {
            if (trackIndex != null && mode() === 'track') noteCompletion();
            trackIndex = idx;
            trackFinished = false;
            if (mode() === 'track') fraction = 0;
            if (mode() === 'track') lastUnitAt = now();
          }
          changed = true;
          continue;
        }

        if ((m = seg.match(DECRYPT_PCT_RE))) {
          reachedDecrypting = true;
          const pct = parseInt(m[1], 10);
          if (Number.isFinite(pct)) fraction = Math.max(0, Math.min(1, pct / 100));
          setSpeed(seg);
          changed = true;
          continue;
        }

        if (DECRYPTED_RE.test(seg) || CONVERSION_DONE_RE.test(seg)) {
          noteCompletion();
          changed = true;
          continue;
        }
      }

      return changed;
    },

    /** Current immutable snapshot. */
    snapshot,

    /** Mark the whole job finished (clamps percent to 100). */
    finish() {
      if (mode() === 'track') {
        if (trackTotal) trackIndex = trackTotal;
        trackFinished = true;
      } else {
        if (queueTotal) queueIndex = queueTotal;
        queueFinished = true;
      }
      fraction = 0;
      return snapshot();
    }
  };
}
