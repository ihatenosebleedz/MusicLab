/**
 * generate-token.js — Generates a 64-character high-entropy secret token.
 */

import { randomBytes } from 'crypto';
import { mkdirSync, writeFileSync, existsSync } from 'fs';
import { dirname } from 'path';
import { config } from '../src/config.js';

const targetFile = config.tokenFile;
mkdirSync(dirname(targetFile), { recursive: true });

if (existsSync(targetFile)) {
  console.log(`Token file already exists at: ${targetFile}`);
  process.exit(0);
}

const token = randomBytes(32).toString('hex');
writeFileSync(targetFile, `${token}\n`, { mode: 0o600 });
console.log(`Generated new secret token at: ${targetFile}`);
