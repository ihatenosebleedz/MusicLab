import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createApp } from '../src/server.js';
import { parseAppleMusicUrl } from '../src/urlParser.js';
import { config } from '../src/config.js';
import { enqueueJob } from '../src/jobRunner.js';
import { getJob } from '../src/db.js';

const app = createApp();

test('URL Parser — valid & invalid URLs', () => {
  const valid = parseAppleMusicUrl('https://music.apple.com/us/album/gnx/1781290351');
  assert.equal(valid.valid, true);
  assert.equal(valid.type, 'album');
  assert.equal(valid.storefront, 'us');

  const songUrl = parseAppleMusicUrl('https://music.apple.com/us/album/gnx/1781290351?i=1781290352');
  assert.equal(songUrl.valid, true);
  assert.equal(songUrl.type, 'song');
  assert.equal(songUrl.id, '1781290352');

  const invalid = parseAppleMusicUrl('https://spotify.com/album/123');
  assert.equal(invalid.valid, false);
});

test('Health endpoint (public)', async () => {
  const server = app.listen(0);
  const port = server.address().port;

  try {
    const res = await fetch(`http://127.0.0.1:${port}/health`);
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.status, 'ok');
    assert.ok(data.services);
  } finally {
    server.close();
  }
});

test('Auth requirement on protected endpoints', async () => {
  const server = app.listen(0);
  const port = server.address().port;

  try {
    const unauthRes = await fetch(`http://127.0.0.1:${port}/jobs`);
    assert.equal(unauthRes.status, 401);

    const token = readFileSync(config.tokenFile, 'utf8').trim();
    const authRes = await fetch(`http://127.0.0.1:${port}/jobs`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });
    assert.equal(authRes.status, 200);
    const data = await authRes.json();
    assert.ok(Array.isArray(data.jobs));
  } finally {
    server.close();
  }
});

test('Job submission, execution with fake-amdl, and inspection', async () => {
  const server = app.listen(0);
  const port = server.address().port;
  const token = readFileSync(config.tokenFile, 'utf8').trim();

  try {
    const testUrl = `https://music.apple.com/us/album/test-album/${Date.now()}`;
    const postRes = await fetch(`http://127.0.0.1:${port}/jobs`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        url: testUrl,
        name: 'Test Artist — Test Album'
      })
    });

    assert.equal(postRes.status, 201);
    const created = await postRes.json();
    assert.equal(created.state, 'queued');
    assert.equal(created.type, 'album');

    // Override runner to use fake-amdl for this test
    enqueueJob(created.id, './tests/fake-amdl.js', process.cwd());

    // Wait for job completion
    let job;
    for (let i = 0; i < 20; i++) {
      await new Promise(r => setTimeout(r, 200));
      const getRes = await fetch(`http://127.0.0.1:${port}/jobs/${created.id}`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      job = await getRes.json();
      if (job.state === 'completed' || job.state === 'failed') break;
    }

    assert.equal(job.state, 'completed');
    assert.equal(job.exitCode, 0);
    assert.ok(job.addedTracks.length > 0);
    assert.equal(job.addedTracks[0].title, 'Mock Track 1');
  } finally {
    server.close();
  }
});

test('Job cancellation endpoint', async () => {
  const server = app.listen(0);
  const port = server.address().port;
  const token = readFileSync(config.tokenFile, 'utf8').trim();

  try {
    const testUrl = `https://music.apple.com/us/album/cancel-test/${Date.now()}`;
    const postRes = await fetch(`http://127.0.0.1:${port}/jobs`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        url: testUrl,
        name: 'Cancel Test'
      })
    });
    const created = await postRes.json();
    // Enqueue job with slow fake-amdl to allow cancelling during run
    enqueueJob(created.id, './tests/fake-amdl.js', process.cwd());

    // Give child process a tick to spawn and enter running state
    await new Promise(r => setTimeout(r, 50));

    const cancelRes = await fetch(`http://127.0.0.1:${port}/jobs/${created.id}/cancel`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    assert.equal(cancelRes.status, 200);
    const cancelData = await cancelRes.json();
    assert.equal(cancelData.state, 'cancelled');
  } finally {
    server.close();
  }
});

test('Invalid Apple Music URL rejection', async () => {
  const server = app.listen(0);
  const port = server.address().port;
  const token = readFileSync(config.tokenFile, 'utf8').trim();

  try {
    const postRes = await fetch(`http://127.0.0.1:${port}/jobs`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        url: 'https://notapplemusic.com/track/123',
        name: 'Invalid Item'
      })
    });

    assert.equal(postRes.status, 400);
    const errorData = await postRes.json();
    assert.equal(errorData.error.code, 'INVALID_URL');
  } finally {
    server.close();
  }
});

