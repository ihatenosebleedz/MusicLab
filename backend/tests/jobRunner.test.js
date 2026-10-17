/**
 * Regression test for the destination working-directory selection.
 *
 * Bug (found live 2026-10-16): the DB hydrator exposes camelCase
 * `destinationPath`, but jobRunner read `job.destination_path` (snake_case),
 * so the per-destination config was never built and amdl always wrote to the
 * repo's default folder. This exercises the exact field the runner uses.
 */

import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

// A throwaway amdl repo with a real-ish config.
const repo = mkdtempSync(join(tmpdir(), 'amdl-repo-'));
writeFileSync(
  join(repo, 'config.yaml'),
  [
    'media-user-token: SECRET-TOKEN-VALUE',
    'alac-save-folder: /mnt/media/Music',
    'atmos-save-folder: /mnt/media/Music',
    'aac-save-folder: /mnt/media/Music',
    'mv-save-folder: /mnt/media/MV',
  ].join('\n')
);
writeFileSync(join(repo, 'config.yaml.example'), 'alac-save-folder: /mnt/media/Music\n');

const { spawnCwdForJob, formatEta } = await import('../src/jobRunner.js');

test('formatEta renders short, minute and hour durations', () => {
  assert.equal(formatEta(0), '0s');
  assert.equal(formatEta(45), '45s');
  assert.equal(formatEta(60), '1m');
  assert.equal(formatEta(130), '2m 10s');
  assert.equal(formatEta(3600), '1h 0m');
  assert.equal(formatEta(3720), '1h 2m');
  assert.equal(formatEta(null), null);
  assert.equal(formatEta(-5), null);
  assert.equal(formatEta(NaN), null);
});

test('spawnCwdForJob uses job.destinationPath (camelCase) and rewrites only save folders', () => {
  const workRoot = mkdtempSync(join(tmpdir(), 'dest-work-'));
  const dest = "/mnt/media/Music/Elijah's Library";

  const cwd = spawnCwdForJob({ destinationPath: dest }, repo, workRoot);

  assert.notEqual(cwd, repo, 'should run from a generated workdir, not the repo dir');
  const cfg = readFileSync(join(cwd, 'config.yaml'), 'utf8');
  assert.match(cfg, /alac-save-folder: \/mnt\/media\/Music\/Elijah's Library/);
  assert.match(cfg, /atmos-save-folder: \/mnt\/media\/Music\/Elijah's Library/);
  assert.match(cfg, /aac-save-folder: \/mnt\/media\/Music\/Elijah's Library/);
  // Unrelated keys (incl. credentials + MV) are preserved untouched.
  assert.match(cfg, /media-user-token: SECRET-TOKEN-VALUE/);
  assert.match(cfg, /mv-save-folder: \/mnt\/media\/MV/);
});

test('spawnCwdForJob reuses the same workdir for the same destination', () => {
  const workRoot = mkdtempSync(join(tmpdir(), 'dest-work-'));
  const a = spawnCwdForJob({ destinationPath: "/mnt/media/Music/Elijah's Library" }, repo, workRoot);
  const b = spawnCwdForJob({ destinationPath: "/mnt/media/Music/Elijah's Library" }, repo, workRoot);
  assert.equal(a, b);
});

test('spawnCwdForJob falls back to the repo dir when no destination is set', () => {
  const workRoot = mkdtempSync(join(tmpdir(), 'dest-work-'));
  assert.equal(spawnCwdForJob({ destinationPath: null }, repo, workRoot), repo);
  assert.equal(spawnCwdForJob({}, repo, workRoot), repo);
});

test('spawnCwdForJob rejects a relative destination path', () => {
  const workRoot = mkdtempSync(join(tmpdir(), 'dest-work-'));
  assert.throws(() => spawnCwdForJob({ destinationPath: 'relative/path' }, repo, workRoot));
});
