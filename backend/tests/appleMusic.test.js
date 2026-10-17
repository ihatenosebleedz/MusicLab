/**
 * Tests for Apple Music catalog playlist expansion.
 *
 * Playlist imports are downloaded per song (so each track lands in its own
 * artist/album folder) using the ordered track list fetched here. The fetch is
 * injected so these tests never touch the network.
 */

import test from 'node:test';
import assert from 'node:assert/strict';
import { fetchPlaylistTracks, songUrl } from '../src/appleMusic.js';
import { resolvePlaylistSongs } from '../src/jobRunner.js';

const TOKEN = 'test-token';

function jsonResponse(body, { ok = true, status = 200 } = {}) {
  return { ok, status, json: async () => body };
}

test('songUrl builds a catalog song page URL', () => {
  assert.equal(songUrl('us', '1805635066'), 'https://music.apple.com/us/song/1805635066');
});

test('fetchPlaylistTracks returns the playlist name and ordered tracks', async () => {
  const calls = [];
  const fetchImpl = async (url) => {
    calls.push(url);
    if (url.endsWith('/playlists/pl.test')) {
      return jsonResponse({ data: [{ id: 'pl.test', attributes: { name: 'Sad' } }] });
    }
    return jsonResponse({
      data: [
        { id: '111', attributes: { name: 'One', artistName: 'A', albumName: 'Alb1' } },
        { id: '222', attributes: { name: 'Two', artistName: 'B', albumName: 'Alb2' } }
      ]
    });
  };

  const { name, tracks } = await fetchPlaylistTracks('us', 'pl.test', { token: TOKEN, fetchImpl });

  assert.equal(name, 'Sad');
  assert.deepEqual(tracks, [
    { id: '111', name: 'One', artistName: 'A', albumName: 'Alb1' },
    { id: '222', name: 'Two', artistName: 'B', albumName: 'Alb2' }
  ]);
  // The track list is requested from the /tracks subresource.
  assert.ok(calls.some((u) => u.includes('/playlists/pl.test/tracks')));
});

test('fetchPlaylistTracks follows pagination in order', async () => {
  const fetchImpl = async (url) => {
    if (url.endsWith('/playlists/pl.page')) {
      return jsonResponse({ data: [{ id: 'pl.page', attributes: { name: 'Big' } }] });
    }
    if (url.includes('offset=100')) {
      return jsonResponse({ data: [{ id: '222', attributes: { name: 'Two' } }] });
    }
    return jsonResponse({
      data: [{ id: '111', attributes: { name: 'One' } }],
      next: '/v1/catalog/us/playlists/pl.page/tracks?limit=100&offset=100'
    });
  };

  const { tracks } = await fetchPlaylistTracks('us', 'pl.page', { token: TOKEN, fetchImpl });
  assert.deepEqual(tracks.map((t) => t.id), ['111', '222']);
});

test('fetchPlaylistTracks throws on a non-OK playlist lookup', async () => {
  const fetchImpl = async () => jsonResponse({}, { ok: false, status: 404 });
  await assert.rejects(
    () => fetchPlaylistTracks('us', 'p.libraryPlaylist', { token: TOKEN, fetchImpl }),
    /playlist lookup failed \(404\)/
  );
});

test('resolvePlaylistSongs expands a catalog playlist into ordered song URLs', async () => {
  const fetchImpl = async (url) => {
    if (url.endsWith('/playlists/pl.sad')) {
      return jsonResponse({ data: [{ id: 'pl.sad', attributes: { name: 'Sad' } }] });
    }
    return jsonResponse({
      data: [
        { id: '111', attributes: { name: 'One' } },
        { id: '222', attributes: { name: 'Two' } }
      ]
    });
  };

  const result = await resolvePlaylistSongs(
    { type: 'playlist', url: 'https://music.apple.com/us/playlist/sad/pl.sad' },
    { token: TOKEN, fetchImpl }
  );

  assert.equal(result.name, 'Sad');
  assert.deepEqual(result.songUrls, [
    'https://music.apple.com/us/song/111',
    'https://music.apple.com/us/song/222'
  ]);
});

test('resolvePlaylistSongs returns null for non-playlist jobs', async () => {
  const result = await resolvePlaylistSongs(
    { type: 'album', url: 'https://music.apple.com/us/album/x/123' },
    { token: TOKEN, fetchImpl: async () => { throw new Error('should not fetch'); } }
  );
  assert.equal(result, null);
});

test('resolvePlaylistSongs returns null when the playlist has no tracks', async () => {
  const fetchImpl = async (url) => {
    if (url.endsWith('/playlists/pl.empty')) {
      return jsonResponse({ data: [{ id: 'pl.empty', attributes: { name: 'Empty' } }] });
    }
    return jsonResponse({ data: [] });
  };

  const result = await resolvePlaylistSongs(
    { type: 'playlist', url: 'https://music.apple.com/us/playlist/empty/pl.empty' },
    { token: TOKEN, fetchImpl }
  );
  assert.equal(result, null);
});
