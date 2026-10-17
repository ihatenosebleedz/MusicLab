/**
 * db.js — SQLite database initialisation and query helpers.
 *
 * Uses built-in node:sqlite (DatabaseSync) which is natively supported
 * on Node 22+ and Node 26 without external native compilation dependencies.
 */

import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'fs';
import { dirname } from 'path';
import { config } from './config.js';

// Ensure data/ directory exists.
mkdirSync(dirname(config.dbPath), { recursive: true });

const db = new DatabaseSync(config.dbPath);

// Enable WAL for better concurrent read performance.
db.exec('PRAGMA journal_mode = WAL;');
db.exec('PRAGMA foreign_keys = ON;');

// ── Schema ──────────────────────────────────────────────────────────────────

db.exec(`
  CREATE TABLE IF NOT EXISTS jobs (
    id                  TEXT PRIMARY KEY,
    type                TEXT NOT NULL,
    url                 TEXT NOT NULL,
    name                TEXT NOT NULL,
    state               TEXT NOT NULL,
    stage               TEXT,
    progress_hint       TEXT,
    progress_percent    REAL,
    progress_completed  INTEGER DEFAULT 0,
    progress_total      INTEGER,
    eta_seconds         INTEGER,
    speed_text          TEXT,
    exit_code           INTEGER,
    stdout_tail         TEXT,
    stderr_tail         TEXT,
    created_at          TEXT NOT NULL,
    updated_at          TEXT NOT NULL,
    started_at          TEXT,
    finished_at         TEXT,
    navidrome_verified  INTEGER DEFAULT 0,
    navidrome_checked_at TEXT,
    navidrome_matches   INTEGER DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS job_tracks (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id   TEXT NOT NULL,
    title    TEXT NOT NULL,
    artist   TEXT NOT NULL,
    album    TEXT NOT NULL,
    path     TEXT NOT NULL,
    FOREIGN KEY(job_id) REFERENCES jobs(id) ON DELETE CASCADE
  );
`);

// ── Migrations ───────────────────────────────────────────────────────────────

function columnExists(table, column) {
  const rows = db.prepare(`PRAGMA table_info(${table})`).all();
  return rows.some((row) => row.name === column);
}

// Per-import destination (server-side id → path map); safe to re-run.
if (!columnExists('jobs', 'destination_id')) {
  db.exec('ALTER TABLE jobs ADD COLUMN destination_id TEXT');
}
if (!columnExists('jobs', 'destination_path')) {
  db.exec('ALTER TABLE jobs ADD COLUMN destination_path TEXT');
}

// Live download progress (percent, songs done/total, ETA, throughput).
if (!columnExists('jobs', 'progress_percent')) {
  db.exec('ALTER TABLE jobs ADD COLUMN progress_percent REAL');
}
if (!columnExists('jobs', 'progress_completed')) {
  db.exec('ALTER TABLE jobs ADD COLUMN progress_completed INTEGER DEFAULT 0');
}
if (!columnExists('jobs', 'progress_total')) {
  db.exec('ALTER TABLE jobs ADD COLUMN progress_total INTEGER');
}
if (!columnExists('jobs', 'eta_seconds')) {
  db.exec('ALTER TABLE jobs ADD COLUMN eta_seconds INTEGER');
}
if (!columnExists('jobs', 'speed_text')) {
  db.exec('ALTER TABLE jobs ADD COLUMN speed_text TEXT');
}

// ── Prepared statements ──────────────────────────────────────────────────────

const stmts = {
  insertJob: db.prepare(`
    INSERT INTO jobs (id, type, url, name, state, stage, progress_hint,
                      destination_id, destination_path, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `),

  updateJob: db.prepare(`
    UPDATE jobs SET
      state             = ?,
      stage             = ?,
      progress_hint     = ?,
      progress_percent  = ?,
      progress_completed = ?,
      progress_total    = ?,
      eta_seconds       = ?,
      speed_text        = ?,
      exit_code         = ?,
      stdout_tail       = ?,
      stderr_tail       = ?,
      started_at        = ?,
      finished_at       = ?,
      navidrome_verified  = ?,
      navidrome_checked_at = ?,
      navidrome_matches   = ?,
      updated_at        = ?
    WHERE id = ?
  `),

  getJob: db.prepare(`SELECT * FROM jobs WHERE id = ?`),

  getJobByUrl: db.prepare(`
    SELECT * FROM jobs
    WHERE url = ?
      AND state IN ('queued', 'resolving', 'downloading', 'processing',
                    'waiting_for_navidrome', 'verifying')
    LIMIT 1
  `),

  listJobsAll: db.prepare(`
    SELECT j.*, COUNT(t.id) AS added_tracks_count
    FROM jobs j
    LEFT JOIN job_tracks t ON t.job_id = j.id
    GROUP BY j.id
    ORDER BY j.created_at DESC
    LIMIT ?
  `),

  listJobsActive: db.prepare(`
    SELECT j.*, COUNT(t.id) AS added_tracks_count
    FROM jobs j
    LEFT JOIN job_tracks t ON t.job_id = j.id
    WHERE j.state IN ('queued','resolving','downloading','processing','waiting_for_navidrome','verifying')
    GROUP BY j.id
    ORDER BY j.created_at DESC
    LIMIT ?
  `),

  listJobsCompleted: db.prepare(`
    SELECT j.*, COUNT(t.id) AS added_tracks_count
    FROM jobs j
    LEFT JOIN job_tracks t ON t.job_id = j.id
    WHERE j.state = 'completed'
    GROUP BY j.id
    ORDER BY j.created_at DESC
    LIMIT ?
  `),

  listJobsFailed: db.prepare(`
    SELECT j.*, COUNT(t.id) AS added_tracks_count
    FROM jobs j
    LEFT JOIN job_tracks t ON t.job_id = j.id
    WHERE j.state IN ('failed','cancelled')
    GROUP BY j.id
    ORDER BY j.created_at DESC
    LIMIT ?
  `),

  insertTrack: db.prepare(`
    INSERT INTO job_tracks (job_id, title, artist, album, path)
    VALUES (?, ?, ?, ?, ?)
  `),

  getTracksForJob: db.prepare(`
    SELECT title, artist, album, path FROM job_tracks WHERE job_id = ?
  `),

  getActiveJobs: db.prepare(`
    SELECT * FROM jobs
    WHERE state IN ('queued','resolving','downloading','processing',
                    'waiting_for_navidrome','verifying')
  `),

  listJobLogRows: db.prepare(`
    SELECT id, stdout_tail, stderr_tail, created_at, updated_at, started_at, finished_at
    FROM jobs
    ORDER BY updated_at DESC
    LIMIT ?
  `),

  getJobLogRow: db.prepare(`
    SELECT id, stdout_tail, stderr_tail, created_at, updated_at, started_at, finished_at
    FROM jobs
    WHERE id = ?
  `),
};

// ── Public API ───────────────────────────────────────────────────────────────

/** Insert a new job row. */
export function insertJob(job) {
  stmts.insertJob.run(
    job.id,
    job.type,
    job.url,
    job.name,
    job.state,
    job.stage,
    job.progress_hint,
    job.destination_id ?? null,
    job.destination_path ?? null,
    job.created_at,
    job.updated_at
  );
}

/** Update mutable job fields. */
export function updateJob(id, fields) {
  const existing = stmts.getJob.get(id);
  if (!existing) throw new Error(`Job ${id} not found`);

  stmts.updateJob.run(
    fields.state              ?? existing.state,
    fields.stage              ?? existing.stage,
    fields.progress_hint      ?? existing.progress_hint,
    fields.progress_percent   ?? existing.progress_percent,
    fields.progress_completed ?? existing.progress_completed,
    fields.progress_total     ?? existing.progress_total,
    fields.eta_seconds        ?? existing.eta_seconds,
    fields.speed_text         ?? existing.speed_text,
    fields.exit_code          ?? existing.exit_code,
    fields.stdout_tail        ?? existing.stdout_tail,
    fields.stderr_tail        ?? existing.stderr_tail,
    fields.started_at         ?? existing.started_at,
    fields.finished_at        ?? existing.finished_at,
    fields.navidrome_verified ?? existing.navidrome_verified,
    fields.navidrome_checked_at ?? existing.navidrome_checked_at,
    fields.navidrome_matches  ?? existing.navidrome_matches,
    new Date().toISOString(),
    id
  );
}

/** Get a single job by ID, including its tracks. Returns null if not found. */
export function getJob(id) {
  const row = stmts.getJob.get(id);
  if (!row) return null;
  return hydrateJob(row);
}

/** Get an active job by Apple Music URL (for duplicate detection). */
export function getActiveJobByUrl(url) {
  const row = stmts.getJobByUrl.get(url);
  return row ? hydrateJob(row) : null;
}

/**
 * List jobs with optional status filter.
 * @param {'active'|'completed'|'failed'|'all'} filter
 * @param {number} limit
 */
export function listJobs(filter = 'all', limit = 50) {
  let rows;
  if (filter === 'active') {
    rows = stmts.listJobsActive.all(limit);
  } else if (filter === 'completed') {
    rows = stmts.listJobsCompleted.all(limit);
  } else if (filter === 'failed') {
    rows = stmts.listJobsFailed.all(limit);
  } else {
    rows = stmts.listJobsAll.all(limit);
  }
  return rows.map(hydrateJobSummary);
}

/** Insert tracks for a completed job. */
export function insertTracks(jobId, tracks) {
  db.exec('BEGIN TRANSACTION;');
  try {
    for (const t of tracks) {
      stmts.insertTrack.run(jobId, t.title, t.artist, t.album, t.path);
    }
    db.exec('COMMIT;');
  } catch (err) {
    db.exec('ROLLBACK;');
    throw err;
  }
}

/** Get all in-progress jobs (used at startup for restart recovery). */
export function getActiveJobs() {
  return stmts.getActiveJobs.all();
}

/** Latest N jobs with their captured amdl output (for GET /logs). */
export function listJobLogRows(limit = 500) {
  return stmts.listJobLogRows.all(limit);
}

/** Single job's captured amdl output, or null if the job does not exist. */
export function getJobLogRow(id) {
  return stmts.getJobLogRow.get(id) ?? null;
}

// ── Hydration helpers ────────────────────────────────────────────────────────

/** Convert snake_case DB row → camelCase API shape (full detail). */
function hydrateJob(row) {
  const tracks = stmts.getTracksForJob.all(row.id);
  return {
    id:           row.id,
    type:         row.type,
    url:          row.url,
    name:         row.name,
    state:        row.state,
    stage:        row.stage,
    progressHint: row.progress_hint,
    progressPercent:   row.progress_percent ?? null,
    progressCompleted: row.progress_completed ?? 0,
    progressTotal:     row.progress_total ?? null,
    etaSeconds:        row.eta_seconds ?? null,
    speedText:         row.speed_text ?? null,
    exitCode:     row.exit_code,
    stdoutTail:   row.stdout_tail,
    stderrTail:   row.stderr_tail,
    destinationId:   row.destination_id,
    destinationPath: row.destination_path,
    createdAt:    row.created_at,
    updatedAt:    row.updated_at,
    startedAt:    row.started_at,
    finishedAt:   row.finished_at,
    addedTracks:  tracks,
    navidrome: {
      verified:  !!row.navidrome_verified,
      checkedAt: row.navidrome_checked_at,
      matches:   row.navidrome_matches,
    },
  };
}

/** Convert snake_case DB row → camelCase API shape (list summary). */
function hydrateJobSummary(row) {
  const tracks = stmts.getTracksForJob.all(row.id);
  return {
    id:               row.id,
    type:             row.type,
    url:              row.url,
    name:             row.name,
    state:            row.state,
    stage:            row.stage,
    progressHint:     row.progress_hint,
    progressPercent:   row.progress_percent ?? null,
    progressCompleted: row.progress_completed ?? 0,
    progressTotal:     row.progress_total ?? null,
    etaSeconds:        row.eta_seconds ?? null,
    speedText:         row.speed_text ?? null,
    exitCode:         row.exit_code,
    stdoutTail:       row.stdout_tail,
    stderrTail:       row.stderr_tail,
    destinationId:    row.destination_id,
    destinationPath:  row.destination_path,
    createdAt:        row.created_at,
    updatedAt:        row.updated_at,
    startedAt:        row.started_at,
    finishedAt:       row.finished_at,
    addedTracksCount: row.added_tracks_count ?? tracks.length,
    addedTracks:      tracks,
    navidrome: {
      verified:  !!row.navidrome_verified,
      checkedAt: row.navidrome_checked_at,
      matches:   row.navidrome_matches,
    },
  };
}
