/**
 * config.js — loads and validates environment configuration.
 *
 * All modules import from here; no module reads process.env directly.
 * Fails fast at startup if required values are missing.
 */

import { readFileSync, existsSync } from 'fs';
import { resolve } from 'path';

/** Load .env file manually (no dotenv dependency). */
function loadDotEnv(path) {
  if (!existsSync(path)) return;
  const text = readFileSync(path, 'utf8');
  for (const line of text.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    const val = trimmed.slice(eq + 1).trim();
    if (!(key in process.env)) process.env[key] = val;
  }
}

loadDotEnv(resolve(process.cwd(), '.env'));

const e = process.env;

/**
 * Parse DESTINATIONS (a JSON object of id -> absolute path).
 * Entries with a non-absolute path are dropped (they could not be a library).
 */
export function parseDestinations(raw) {
  if (!raw || !raw.trim()) return {};
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (err) {
    throw new Error(`DESTINATIONS is not valid JSON: ${err.message}`);
  }
  if (typeof parsed !== 'object' || Array.isArray(parsed) || parsed === null) {
    throw new Error('DESTINATIONS must be a JSON object of { "<id>": "<absolute path>" }.');
  }
  const map = {};
  for (const [id, path] of Object.entries(parsed)) {
    if (!id.trim()) continue;
    if (typeof path !== 'string' || !path.startsWith('/')) {
      console.warn(`[config] ignoring destination "${id}": path must be absolute.`);
      continue;
    }
    map[id] = path;
  }
  return map;
}

export const config = {
  port: parseInt(e.PORT ?? '3000', 10),
  host: e.HOST ?? '0.0.0.0',

  tokenFile: resolve(e.TOKEN_FILE ?? './data/token.secret'),
  dbPath:    resolve(e.DB_PATH    ?? './data/jobs.db'),

  amdl: {
    cwd: e.AMDL_CWD ?? '/home/nbz/apple-music-downloader',
    bin: e.AMDL_BIN ?? './amdl',
  },

  navidrome: {
    url:        e.NAVIDROME_URL  ?? 'http://127.0.0.1:4533',
    user:       e.NAVIDROME_USER ?? '',
    pass:       e.NAVIDROME_PASS ?? '',
    token:      e.NAVIDROME_TOKEN ?? '',
    salt:       e.NAVIDROME_SALT  ?? '',
    musicFolder: e.MUSIC_FOLDER  ?? '/mnt/media/Music',
  },

  wrapperLite: {
    url: e.WRAPPER_LITE_URL ?? 'http://127.0.0.1:12340',
  },

  // Log sources for GET /logs. Empty path => that source is unavailable.
  logs: {
    file:       e.LOG_FILE       ?? '',
    wrapperFile: e.WRAPPER_LOG_FILE ?? '',
    maxFileLines: parseInt(e.LOG_MAX_LINES ?? '2000', 10),
  },

  // Server-side destination id -> absolute path map (steers amdl save folders).
  destinations: {
    map: parseDestinations(e.DESTINATIONS),
    defaultId: e.DEFAULT_DESTINATION ?? '',
  },
};

// Resolve the default destination id once, so every consumer agrees on it.
{
  const ids = Object.keys(config.destinations.map);
  if (!config.destinations.defaultId && ids.length > 0) {
    config.destinations.defaultId = ids[0];
  }
  if (config.destinations.defaultId && !(config.destinations.defaultId in config.destinations.map)) {
    throw new Error(
      `DEFAULT_DESTINATION "${config.destinations.defaultId}" is not present in DESTINATIONS ` +
      `(known ids: ${ids.join(', ') || 'none'}).`
    );
  }
}
