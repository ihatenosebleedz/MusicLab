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
};
