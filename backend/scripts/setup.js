/**
 * setup.js — One-time backend setup script.
 *
 * Generates a bearer token, ensures the data directory exists,
 * and prints the token for use with the app.
 */

import { mkdirSync, existsSync } from 'fs';
import { resolve } from 'path';
import { createHash, randomBytes } from 'crypto';

const DATA_DIR = resolve('./data');

// Ensure data directory exists
if (!existsSync(DATA_DIR)) {
  mkdirSync(DATA_DIR, { recursive: true });
  console.log(`Created data directory: ${DATA_DIR}`);
}

// Generate a 64-character hex bearer token
const token = randomBytes(32).toString('hex');
console.log(`\nBearer Token (save this — it will not be shown again):\n  ${token}\n`);
console.log('Configure this token in your MusicLab app Settings > Bearer Token.');
console.log('The token is stored in data/token.secret and required for all API requests.\n');

// Write token to file
const tokenPath = resolve(DATA_DIR, 'token.secret');
import { writeFileSync } from 'fs';
writeFileSync(tokenPath, token, { mode: 0o600 });
console.log(`Token written to: ${tokenPath}`);