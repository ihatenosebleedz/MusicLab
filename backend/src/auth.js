/**
 * auth.js — Bearer token authentication middleware.
 *
 * Token is loaded from the file specified in config.tokenFile.
 * Comparison uses crypto.timingSafeEqual to prevent timing attacks.
 */

import { readFileSync, existsSync } from 'fs';
import { createHash, timingSafeEqual } from 'crypto';
import { config } from './config.js';

/** Load the secret token from disk. Cached after first read. */
let _tokenBuf = null;

function getTokenBuf() {
  if (_tokenBuf) return _tokenBuf;
  if (!existsSync(config.tokenFile)) {
    throw new Error(
      `Token file not found at ${config.tokenFile}. ` +
      `Run \`npm run generate-token\` to create one.`
    );
  }
  const raw = readFileSync(config.tokenFile, 'utf8').trim();
  if (raw.length < 32) {
    throw new Error(`Token in ${config.tokenFile} is too short (min 32 chars).`);
  }
  _tokenBuf = Buffer.from(raw);
  return _tokenBuf;
}

/** Force reload of token (used in tests). */
export function resetTokenCache() {
  _tokenBuf = null;
}

/**
 * Best-effort access to the live secret, used only to redact it out of
 * log responses. Returns null when the token is unavailable.
 */
export function peekToken() {
  try {
    return getTokenBuf().toString('utf8');
  } catch {
    return null;
  }
}

/**
 * Express middleware: rejects requests without a valid Bearer token.
 * Returns 401 with structured error on failure.
 */
export function requireAuth(req, res, next) {
  const header = req.headers['authorization'] ?? '';
  const match  = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return res.status(401).json({
      error: { code: 'UNAUTHORIZED', message: 'Missing Authorization: Bearer <token> header.' }
    });
  }

  let tokenBuf;
  try {
    tokenBuf = getTokenBuf();
  } catch (err) {
    console.error('[auth] token load error:', err.message);
    return res.status(500).json({
      error: { code: 'SERVER_ERROR', message: 'Token configuration error.' }
    });
  }

  const provided = Buffer.from(match[1]);
  // Pad to same length before timingSafeEqual (it requires equal-length buffers).
  const maxLen = Math.max(tokenBuf.length, provided.length);
  const a = Buffer.alloc(maxLen);
  const b = Buffer.alloc(maxLen);
  tokenBuf.copy(a);
  provided.copy(b);

  if (!timingSafeEqual(a, b)) {
    return res.status(401).json({
      error: { code: 'UNAUTHORIZED', message: 'Invalid bearer token.' }
    });
  }

  next();
}
