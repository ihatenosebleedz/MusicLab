/**
 * Regression tests for playlist file generation.
 *
 * Bug (found live 2026-10-17): playlist .m3u8 files were written to
 * "<MUSIC_FOLDER>/Playlists", which is outside every Navidrome library, so
 * Navidrome never imported them. They must be written inside the destination
 * library.
 */

import test from 'node:test';
import assert from 'node:assert/strict';
import {
  sanitizePlaylistName,
  playlistFilePath,
  buildPlaylistM3U8
} from '../src/playlistFile.js';

test('sanitizePlaylistName strips path-unsafe characters and collapses whitespace', () => {
  assert.equal(sanitizePlaylistName('Sad'), 'Sad');
  assert.equal(sanitizePlaylistName('a/b\\c:d*e?f"g<h>i|j'), 'a_b_c_d_e_f_g_h_i_j');
  assert.equal(sanitizePlaylistName('  spaced   out  '), 'spaced out');
  assert.equal(sanitizePlaylistName('line\nbreak'), 'line break');
});

test('playlistFilePath writes inside the destination library', () => {
  const dest = "/mnt/media/Music/Elijah's Library";
  assert.equal(
    playlistFilePath(dest, 'Sad'),
    "/mnt/media/Music/Elijah's Library/Sad.m3u8"
  );
});

test('playlistFilePath falls back to "playlist" when the name is empty', () => {
  assert.equal(playlistFilePath('/music/Lib', '   '), '/music/Lib/playlist.m3u8');
});

test('buildPlaylistM3U8 preserves track order and uses absolute paths', () => {
  const tracks = [
    { artist: 'The Flat Stanleys', title: 'Me vs Your Friends', path: "/lib/A/01. Me vs Your Friends.flac" },
    { artist: 'bunii', title: 'COYOTES', path: "/lib/B/05. COYOTES.flac" }
  ];

  const out = buildPlaylistM3U8('Sad', tracks);
  const lines = out.split('\n');

  assert.equal(lines[0], '#EXTM3U');
  assert.equal(lines[1], '#PLAYLIST:Sad');
  assert.equal(lines[2], '#EXTINF:-1,The Flat Stanleys - Me vs Your Friends');
  assert.equal(lines[3], "/lib/A/01. Me vs Your Friends.flac");
  assert.equal(lines[4], '#EXTINF:-1,bunii - COYOTES');
  assert.equal(lines[5], "/lib/B/05. COYOTES.flac");
  assert.ok(out.endsWith('\n'));
});

test('buildPlaylistM3U8 omits the #PLAYLIST tag when the name is empty', () => {
  const out = buildPlaylistM3U8('', [{ artist: 'X', title: 'Y', path: '/p/y.flac' }]);
  assert.ok(!out.includes('#PLAYLIST:'));
  assert.ok(out.includes('/p/y.flac'));
});
