/**
 * Tests for the amdl stdout → live progress parser.
 *
 * amdl pipes '\r'-overwritten progress updates (not a TTY), so tokens must be
 * split on /[\r\n]+/ and partial lines carried across chunk boundaries.
 */

import test from 'node:test';
import assert from 'node:assert/strict';
import { createProgressTracker } from '../src/amdlProgress.js';

/** Deterministic clock for ETA assertions. */
function clock(startMs = 1_000_000) {
  let t = startMs;
  const now = () => t;
  now.advance = (ms) => { t += ms; };
  return now;
}

test('tracks per-song percent with an expected total before any Queue line', () => {
  const now = clock();
  const p = createProgressTracker({ expectedTotal: 4, now });

  p.feed('Decrypting...  50%  (24/49 MB, 11 MB/s)');
  const s = p.snapshot();
  assert.equal(s.total, 4);
  assert.equal(s.percent, 12.5); // half of one song out of four
  assert.equal(s.speedText, '11 MB/s');
  assert.equal(s.etaSeconds, null); // no completed song yet
});

test('splits a chunk carrying many \\r-overwritten updates', () => {
  const p = createProgressTracker({ expectedTotal: 2, now: clock() });
  p.feed('Decrypting...  10%  (5/49 MB, 3 MB/s)\rDecrypting...  60%  (30/49 MB, 12 MB/s)\rDecrypting... 100%  (49/49 MB, 10 MB/s)');
  const s = p.snapshot();
  assert.equal(s.speedText, '10 MB/s');
  assert.equal(s.percent, 50); // one full song out of two
});

test('parses a split Queue/Decrypted stream and computes ETA', () => {
  const now = clock();
  const p = createProgressTracker({ expectedTotal: 3, now });

  p.feed('Queue 1 of 3: Song->Artist A\n');
  p.feed('Track 1 of 12: songs\n');
  p.feed('Decrypting...  20%  (10/49 MB, 5 MB/s)\n');
  assert.equal(p.snapshot().percent, 6.7); // 0.2/3

  now.advance(10_000); // song 1 took 10s
  p.feed('[10s] Decrypted\nConversion completed in 424ms: 01. A.flac\n');
  const afterOne = p.snapshot();
  assert.equal(afterOne.completed, 1);
  assert.equal(afterOne.percent, 33.3);
  assert.equal(afterOne.etaSeconds, 20); // 10s/song × 2 remaining

  // The next Queue line rolls over to song 2 (previous one already counted).
  p.feed('Queue 2 of 3: Song->Artist B\n');
  assert.equal(p.snapshot().completed, 1);
  assert.equal(p.snapshot().percent, 33.3);
});

test('Queue index alone implies earlier songs completed', () => {
  const p = createProgressTracker({ now: clock() });
  p.feed('Queue 1 of 5: Song->A\n');
  p.feed('Queue 2 of 5: Song->B\n');
  assert.equal(p.snapshot().completed, 1);
  assert.equal(p.snapshot().percent, 20);
  p.feed('Queue 5 of 5: Song->E\n');
  assert.equal(p.snapshot().completed, 4);
  assert.equal(p.snapshot().percent, 80);
});

test('carries partial tokens across chunk boundaries', () => {
  // Simulate jobRunner's buffering: incomplete trailing segment is retained.
  const p = createProgressTracker({ expectedTotal: 1, now: clock() });
  let pending = '';
  const feed = (chunk) => {
    const combined = pending + chunk;
    const parts = combined.split(/[\r\n]/);
    pending = parts.pop();
    p.feed(parts.join('\n'));
  };

  feed('Queue 1 of 1: Song->Neon Trees\nDecry');
  feed('pting...  74%  (36/49 MB, 11 MB/s)\n');
  const s = p.snapshot();
  assert.equal(s.speedText, '11 MB/s');
  assert.equal(s.percent, 74);
});

test('finish() clamps percent to 100', () => {
  const p = createProgressTracker({ expectedTotal: 3, now: clock() });
  p.feed('Queue 1 of 3: Song->A\nDecrypting... 40% (20/49 MB, 5 MB/s)\n');
  const done = p.finish();
  assert.equal(done.percent, 100);
  assert.equal(done.completed, 3);
  assert.equal(done.etaSeconds, 0);
});

test('album (single URL) uses Track x of N for progress', () => {
  const p = createProgressTracker({ expectedTotal: 1, now: clock() });
  p.feed('Queue 1 of 1: Song->Album\nTrack 1 of 3: songs\nDecrypting...  50%  (10/20 MB, 5 MB/s)\n');
  let s = p.snapshot();
  assert.equal(s.mode, 'track');
  assert.equal(s.total, 3);
  assert.equal(s.completed, 0);
  assert.equal(s.percent, 16.7); // half of track 1 of 3

  p.feed('[2s] Decrypted\nTrack 2 of 3: songs\n');
  s = p.snapshot();
  assert.equal(s.completed, 1);
  assert.equal(s.percent, 33.3);
});

test('playlist mode ignores per-album Track lines', () => {
  const p = createProgressTracker({ expectedTotal: 2, now: clock() });
  p.feed('Queue 1 of 2: Song->A\nTrack 3 of 12: songs\nDecrypting... 100%  (49/49 MB, 10 MB/s)\n');
  const s = p.snapshot();
  assert.equal(s.mode, 'queue');
  assert.equal(s.total, 2);
  assert.equal(s.completed, 0);
  assert.equal(s.percent, 50);
});

test('no total yields null percent but still reports speed', () => {
  const p = createProgressTracker({ now: clock() });
  p.feed('Decrypting...  74%  (36/49 MB, 11 MB/s)\n');
  const s = p.snapshot();
  assert.equal(s.total, null);
  assert.equal(s.percent, null);
  assert.equal(s.speedText, '11 MB/s');
  assert.equal(s.downloading, true);
});
