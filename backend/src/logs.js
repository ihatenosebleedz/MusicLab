/**
 * logs.js — authenticated, paginated, redacted log aggregation.
 *
 * Sources:
 *   backend — backend service log file (LOG_FILE), if configured
 *   job     — per-job amdl stdout/stderr tails persisted in SQLite
 *   wrapper — wrapper-lite log file (WRAPPER_LOG_FILE), if configured
 *
 * Nothing in here ever returns a secret: every line passes through `redact()`
 * which masks both well-known credential shapes and the actual secret values.
 */

import { Router } from 'express';
import { readFileSync, statSync } from 'fs';
import { config } from './config.js';
import { peekToken } from './auth.js';
import { listJobLogRows, getJobLogRow } from './db.js';

export const logsRouter = Router();

const SOURCES = ['all', 'backend', 'job', 'wrapper'];
const MAX_LIMIT = 500;

// ── Redaction ────────────────────────────────────────────────────────────────

/** Credential-shaped patterns (name = value / name: value / Bearer <jwt>). */
const SECRET_PATTERNS = [
  [/\bBearer\s+[A-Za-z0-9._~+/=-]{8,}/gi, 'Bearer [REDACTED]'],
  [
    /\b(media-user-token|authorization-token|access-token|refresh-token|authorization|password|passwd|pwd|secret|api[-_]?key|bearer|token)(\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;"'}]+)/gi,
    '$1$2[REDACTED]'
  ],
];

/** Exact live secret values that must never appear in any response. */
function secretValues() {
  const out = [];
  const push = (v) => {
    if (typeof v === 'string' && v.trim().length >= 6) out.push(v.trim());
  };
  push(config.navidrome.pass);
  push(config.navidrome.token);
  push(peekToken());
  return out;
}

/** Strip credentials from a log line. Exported for reuse/testing. */
export function redact(text) {
  if (typeof text !== 'string' || text.length === 0) return text;
  let out = text;
  for (const [re, replacement] of SECRET_PATTERNS) {
    out = out.replace(re, replacement);
  }
  for (const secret of secretValues()) {
    if (out.includes(secret)) out = out.split(secret).join('[REDACTED]');
  }
  return out;
}

// ── Source readers ───────────────────────────────────────────────────────────

function readFileEntries(path, source) {
  if (!path) return { available: false, entries: [] };
  let raw;
  let mtime;
  try {
    const stat = statSync(path);
    mtime = new Date(stat.mtimeMs).toISOString();
    raw = readFileSync(path, 'utf8');
  } catch {
    return { available: false, entries: [] };
  }

  const lines = raw.split('\n');
  while (lines.length && lines[lines.length - 1] === '') lines.pop();
  const recent = lines.slice(-config.logs.maxFileLines);

  // File lines carry the file mtime (best effort); `seq` keeps file order.
  const entries = recent.map((line, i) => ({
    source,
    stream: 'service',
    at: mtime,
    seq: i,
    line: redact(line),
  }));
  return { available: true, entries };
}

function jobEntries(jobId) {
  const rows = jobId ? [getJobLogRow(jobId)].filter(Boolean) : listJobLogRows(500);
  const entries = [];

  for (const row of rows) {
    const at = row.finished_at || row.updated_at || row.started_at || row.created_at || null;
    const tails = [
      ['stdout', row.stdout_tail],
      ['stderr', row.stderr_tail],
    ];
    for (const [stream, tail] of tails) {
      if (!tail) continue;
      for (const line of String(tail).split('\n')) {
        if (line === '') continue;
        entries.push({
          source: 'job',
          jobId: row.id,
          stream,
          at,
          seq: entries.length,
          line: redact(line),
        });
      }
    }
  }
  return { available: rows.length > 0, entries };
}

// ── Route ────────────────────────────────────────────────────────────────────

/**
 * GET /logs?source=all|backend|job|wrapper&jobId=<uuid>&limit=&offset=
 * 401 (auth) | 400 (bad params) | 200 { logs, page, available }
 */
logsRouter.get('/', (req, res) => {
  const { source = 'all', jobId, limit = '100', offset = '0' } = req.query;

  if (!SOURCES.includes(source)) {
    return res.status(400).json({
      error: {
        code: 'INVALID_SOURCE',
        message: `source must be one of: ${SOURCES.join(', ')}.`
      }
    });
  }

  const parsedLimit = parseInt(limit, 10);
  const parsedOffset = parseInt(offset, 10);
  const pageLimit = Math.min(Math.max(Number.isFinite(parsedLimit) ? parsedLimit : 100, 1), MAX_LIMIT);
  const pageOffset = Math.min(Math.max(Number.isFinite(parsedOffset) ? parsedOffset : 0, 0), 1_000_000);

  if (jobId) {
    const job = getJobLogRow(jobId);
    if (!job) {
      return res.status(404).json({
        error: {
          code: 'JOB_NOT_FOUND',
          message: `Job ${jobId} does not exist.`
        }
      });
    }
  }

  const available = {};
  let entries = [];

  if (jobId) {
    // A jobId scopes the result to that job's captured output only.
    const result = jobEntries(jobId);
    available.job = result.available;
    entries.push(...result.entries);
  } else {
    if (source === 'all' || source === 'backend') {
      const result = readFileEntries(config.logs.file, 'backend');
      available.backend = result.available;
      entries.push(...result.entries);
    }

    if (source === 'all' || source === 'wrapper') {
      const result = readFileEntries(config.logs.wrapperFile, 'wrapper');
      available.wrapper = result.available;
      entries.push(...result.entries);
    }

    if (source === 'all' || source === 'job') {
      const result = jobEntries();
      available.job = result.available;
      entries.push(...result.entries);
    }
  }

  // Newest first; within an identical timestamp prefer the later line.
  entries.sort((a, b) => {
    const atA = a.at ?? '0000';
    const atB = b.at ?? '0000';
    if (atA !== atB) return atA < atB ? 1 : -1;
    return (b.seq ?? 0) - (a.seq ?? 0);
  });

  const total = entries.length;
  const logs = entries.slice(pageOffset, pageOffset + pageLimit)
    .map(({ seq: _seq, ...rest }) => rest);

  return res.json({
    logs,
    page: {
      limit: pageLimit,
      offset: pageOffset,
      total,
      hasMore: pageOffset + pageLimit < total
    },
    available
  });
});
