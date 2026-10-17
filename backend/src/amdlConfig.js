/**
 * amdlConfig.js — builds a per-destination amdl working directory.
 *
 * amdl resolves its configuration with a plain relative read:
 *   internal/app/config.go: os.ReadFile("config.yaml")
 * and exposes no --dest/--output flag, so the ONLY way to steer where an
 * individual job writes is to run amdl from a working directory whose
 * config.yaml carries the desired `*-save-folder` values.
 *
 * We therefore copy the real config (preserving credentials and every other
 * setting) and rewrite ONLY the save-folder keys.
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync, copyFileSync } from 'fs';
import { dirname, join } from 'path';
import { createHash } from 'crypto';

/** Save-folder keys amdl honours for audio output. */
const AUDIO_SAVE_KEYS = ['alac', 'atmos', 'aac'];

/**
 * Rewrite only the `*-save-folder` keys, preserving indentation, any trailing
 * comment, and every other line (including credentials) byte-for-byte.
 * @param {string} baseConfigText
 * @param {string} destPath absolute destination path
 * @returns {string}
 */
export function applyDestination(baseConfigText, destPath) {
  if (typeof destPath !== 'string' || !destPath.startsWith('/')) {
    throw new Error(`Destination path must be absolute, got: ${JSON.stringify(destPath)}`);
  }

  const seen = new Set();
  const out = baseConfigText.split('\n').map((line) => {
    const match = line.match(/^(\s*)(alac|atmos|aac)-save-folder:(.*)$/);
    if (!match) return line;

    const [, indent, key, rest] = match;
    seen.add(key);
    const hashIndex = rest.indexOf('#');
    const comment = hashIndex >= 0 ? rest.slice(hashIndex) : '';
    return `${indent}${key}-save-folder: ${destPath}${comment ? '   ' + comment : ''}`;
  });

  // Preserve keys the base config never defined (amdl would otherwise fall back
  // to config.yaml.example defaults, i.e. the wrong folder again).
  for (const key of AUDIO_SAVE_KEYS) {
    if (!seen.has(key)) out.push(`${key}-save-folder: ${destPath}`);
  }

  return out.join('\n');
}

/**
 * Materialise a working directory containing a config.yaml that writes to
 * `destPath`, and return that directory.
 *
 * @param {string} baseCwd   amdl repository dir (source of the real config)
 * @param {string} destPath  absolute destination path
 * @param {string} workRoot  parent dir for generated work dirs
 * @returns {string} absolute working directory
 */
export function buildDestinationCwd(baseCwd, destPath, workRoot) {
  const baseConfigPath = join(baseCwd, 'config.yaml');
  if (!existsSync(baseConfigPath)) {
    throw new Error(`amdl config not found at ${baseConfigPath}`);
  }

  const modified = applyDestination(readFileSync(baseConfigPath, 'utf8'), destPath);

  // Stable per-destination dir so repeated jobs reuse the same generated config.
  const slug = createHash('sha1').update(destPath).digest('hex').slice(0, 12);
  const workdir = join(workRoot, slug);
  mkdirSync(workdir, { recursive: true });

  writeFileSync(join(workdir, 'config.yaml'), modified, 'utf8');

  // amdl warns (but continues) without the example file; copying it keeps the
  // generated dir equivalent to running from the real repository.
  const examplePath = join(baseCwd, 'config.yaml.example');
  if (existsSync(examplePath)) {
    copyFileSync(examplePath, join(workdir, 'config.yaml.example'));
  }

  return workdir;
}
