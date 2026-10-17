import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// Configure destinations BEFORE config.js is imported.
const BRYON = "/mnt/media/Music/Bryon's Library";
const ELIJAH = "/mnt/media/Music/Elijah's Library";

process.env.DESTINATIONS = JSON.stringify({ bryon: BRYON, elijah: ELIJAH });
process.env.DEFAULT_DESTINATION = 'bryon';

const { createApp } = await import('../src/server.js');
const { config, parseDestinations } = await import('../src/config.js');
const { applyDestination } = await import('../src/amdlConfig.js');

const app = createApp();
const token = readFileSync(config.tokenFile, 'utf8').trim();
const auth = { Authorization: `Bearer ${token}` };

function listen() {
  const server = app.listen(0);
  return { server, port: server.address().port };
}

function submit(port, body) {
  return fetch(`http://127.0.0.1:${port}/jobs`, {
    method: 'POST',
    headers: { ...auth, 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });
}

test('DESTINATIONS is parsed into an id→path map with a resolved default', () => {
  assert.deepEqual(config.destinations.map, { bryon: BRYON, elijah: ELIJAH });
  assert.equal(config.destinations.defaultId, 'bryon');
});

test('parseDestinations rejects malformed JSON and drops relative paths', () => {
  assert.throws(() => parseDestinations('{ not json'), /not valid JSON/);
  assert.deepEqual(parseDestinations('{"ok":"/abs","bad":"relative"}'), { ok: '/abs' });
  assert.deepEqual(parseDestinations(''), {});
});

test('GET /destinations lists ids and default without leaking paths', async () => {
  const { server, port } = listen();
  try {
    const res = await fetch(`http://127.0.0.1:${port}/destinations`, { headers: auth });
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.defaultId, 'bryon');
    assert.deepEqual(data.destinations.map((d) => d.id).sort(), ['bryon', 'elijah']);
    assert.equal(data.destinations.find((d) => d.id === 'bryon').isDefault, true);
    assert.doesNotMatch(JSON.stringify(data), /\/mnt\/media/);
  } finally {
    server.close();
  }
});

test('POST /jobs rejects an unknown destinationId', async () => {
  const { server, port } = listen();
  try {
    const res = await submit(port, {
      url: `https://music.apple.com/us/album/bad-dest/${Date.now()}`,
      destinationId: 'nope'
    });
    assert.equal(res.status, 400);
    assert.equal((await res.json()).error.code, 'INVALID_DESTINATION');
  } finally {
    server.close();
  }
});

test('POST /jobs records the requested destination on the job', async () => {
  const { server, port } = listen();
  try {
    const res = await submit(port, {
      url: `https://music.apple.com/us/album/elijah-album/${Date.now()}`,
      name: 'Elijah Album',
      destinationId: 'elijah'
    });
    assert.equal(res.status, 201);
    const created = await res.json();
    assert.equal(created.destinationId, 'elijah');
    assert.equal(created.destinationPath, ELIJAH);
  } finally {
    server.close();
  }
});

test('POST /jobs defaults to the configured destination when omitted', async () => {
  const { server, port } = listen();
  try {
    const res = await submit(port, {
      url: `https://music.apple.com/us/album/default-album/${Date.now()}`,
      name: 'Default Album'
    });
    assert.equal(res.status, 201);
    const created = await res.json();
    assert.equal(created.destinationId, 'bryon');
    assert.equal(created.destinationPath, BRYON);
  } finally {
    server.close();
  }
});

test('applyDestination rewrites only the save-folder keys', () => {
  const base = [
    'media-user-token: "SECRETTOKEN"',
    'alac-save-folder: /mnt/media/Music',
    'atmos-save-folder: /mnt/media/Music   # keep me',
    'aac-save-folder: /mnt/media/Music',
    'lite-server: "http://127.0.0.1:12340"'
  ].join('\n');

  const out = applyDestination(base, BRYON);

  assert.match(out, /media-user-token: "SECRETTOKEN"/);
  assert.match(out, /lite-server: "http:\/\/127\.0\.0\.1:12340"/);
  assert.match(out, /alac-save-folder: \/mnt\/media\/Music\/Bryon's Library/);
  assert.match(out, /aac-save-folder: \/mnt\/media\/Music\/Bryon's Library/);
  assert.match(out, /atmos-save-folder: \/mnt\/media\/Music\/Bryon's Library\s+# keep me/);
  assert.equal(out.match(/\/mnt\/media\/Music(?!\/)/g), null);
});

test('applyDestination adds missing keys and rejects relative paths', () => {
  const out = applyDestination('media-user-token: "x"', ELIJAH);
  assert.match(out, /alac-save-folder: \/mnt\/media\/Music\/Elijah's Library/);
  assert.match(out, /atmos-save-folder: \/mnt\/media\/Music\/Elijah's Library/);
  assert.match(out, /aac-save-folder: \/mnt\/media\/Music\/Elijah's Library/);

  assert.throws(() => applyDestination('a: b', 'relative/path'), /absolute/);
});
