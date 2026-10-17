import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// Configure log sources + a fake credential BEFORE config.js is imported.
const dir = mkdtempSync(join(tmpdir(), 'musiclab-logs-'));
const backendLog = join(dir, 'backend.log');
const wrapperLog = join(dir, 'wrapper.log');

process.env.LOG_FILE = backendLog;
process.env.WRAPPER_LOG_FILE = wrapperLog;
process.env.NAVIDROME_PASS = 'super-secret-navidrome-pass';

writeFileSync(
  backendLog,
  [
    'server started',
    'Authorization: Bearer abcdefghijklmnop',
    'token=topsecretvalue123',
    'using password super-secret-navidrome-pass',
    'job accepted',
  ].join('\n')
);
writeFileSync(wrapperLog, 'wrapper-lite listening on 127.0.0.1:12340');

const { createApp } = await import('../src/server.js');
const { config } = await import('../src/config.js');
const { redact } = await import('../src/logs.js');
const { enqueueJob } = await import('../src/jobRunner.js');

const app = createApp();
const token = readFileSync(config.tokenFile, 'utf8').trim();
const auth = { Authorization: `Bearer ${token}` };

function listen() {
  const server = app.listen(0);
  return { server, port: server.address().port };
}

test('redact() masks bearer tokens, name=value secrets, and exact credentials', () => {
  assert.doesNotMatch(redact('Authorization: Bearer abcdefghijklmnop'), /abcdefghijklmnop/);
  assert.doesNotMatch(redact('token=topsecretvalue123'), /topsecretvalue123/);
  assert.doesNotMatch(redact('x super-secret-navidrome-pass y'), /super-secret-navidrome-pass/);
  assert.equal(redact('plain line'), 'plain line');
});

test('GET /logs requires authentication', async () => {
  const { server, port } = listen();
  try {
    const res = await fetch(`http://127.0.0.1:${port}/logs`);
    assert.equal(res.status, 401);
  } finally {
    server.close();
  }
});

test('GET /logs?source=backend returns redacted service lines', async () => {
  const { server, port } = listen();
  try {
    const res = await fetch(`http://127.0.0.1:${port}/logs?source=backend`, { headers: auth });
    assert.equal(res.status, 200);
    const data = await res.json();

    assert.equal(data.available.backend, true);
    assert.ok(data.logs.length > 0);
    assert.ok(data.logs.every((l) => l.source === 'backend'));

    const text = JSON.stringify(data);
    assert.doesNotMatch(text, /abcdefghijklmnop/);
    assert.doesNotMatch(text, /topsecretvalue123/);
    assert.doesNotMatch(text, /super-secret-navidrome-pass/);
    assert.ok(data.logs.some((l) => l.line.includes('[REDACTED]')));
  } finally {
    server.close();
  }
});

test('GET /logs?source=wrapper reports wrapper availability', async () => {
  const { server, port } = listen();
  try {
    const res = await fetch(`http://127.0.0.1:${port}/logs?source=wrapper`, { headers: auth });
    const data = await res.json();
    assert.equal(data.available.wrapper, true);
    assert.ok(data.logs.every((l) => l.source === 'wrapper'));
  } finally {
    server.close();
  }
});

test('GET /logs validates source, jobId, and paginates', async () => {
  const { server, port } = listen();
  try {
    const bad = await fetch(`http://127.0.0.1:${port}/logs?source=bogus`, { headers: auth });
    assert.equal(bad.status, 400);
    assert.equal((await bad.json()).error.code, 'INVALID_SOURCE');

    const missing = await fetch(`http://127.0.0.1:${port}/logs?jobId=does-not-exist`, { headers: auth });
    assert.equal(missing.status, 404);

    const paged = await fetch(`http://127.0.0.1:${port}/logs?source=backend&limit=2`, { headers: auth });
    const data = await paged.json();
    assert.equal(data.page.limit, 2);
    assert.ok(data.logs.length <= 2);
    assert.ok(data.page.total >= 5);
    assert.equal(data.page.hasMore, data.page.total > 2);
  } finally {
    server.close();
  }
});

test('GET /logs?jobId= returns that job\'s captured amdl output', async () => {
  const { server, port } = listen();
  try {
    const url = `https://music.apple.com/us/album/logs-test/${Date.now()}`;
    const postRes = await fetch(`http://127.0.0.1:${port}/jobs`, {
      method: 'POST',
      headers: { ...auth, 'Content-Type': 'application/json' },
      body: JSON.stringify({ url, name: 'Logs Test' })
    });
    const created = await postRes.json();
    enqueueJob(created.id, './tests/fake-amdl.js', process.cwd());

    let job;
    for (let i = 0; i < 20; i++) {
      await new Promise((r) => setTimeout(r, 200));
      const r = await fetch(`http://127.0.0.1:${port}/jobs/${created.id}`, { headers: auth });
      job = await r.json();
      if (job.state === 'completed' || job.state === 'failed') break;
    }
    assert.equal(job.state, 'completed');

    const res = await fetch(`http://127.0.0.1:${port}/logs?jobId=${created.id}`, { headers: auth });
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.ok(data.logs.length > 0);
    assert.ok(data.logs.every((l) => l.source === 'job' && l.jobId === created.id));
  } finally {
    server.close();
  }
});
