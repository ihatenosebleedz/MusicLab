/**
 * playlistFile.js — builds Navidrome-visible .m3u8 playlist files.
 *
 * Navidrome only imports M3U playlists found inside a configured library path
 * (PlaylistsPath defaults to every folder under each library). The previous
 * implementation wrote playlists to "<MUSIC_FOLDER>/Playlists", which sits
 * *outside* every library, so Navidrome never saw them. Playlists are now
 * written into the job's destination library.
 *
 * Track paths are stored absolute (amdl emits absolute paths), which Navidrome
 * resolves directly and maps to the owning library.
 */

import { join } from 'path';

/** Strip characters that are illegal or meaningful in filenames/paths. */
export function sanitizePlaylistName(name) {
  return String(name ?? '')
    .replace(/[/\\?%*:|"<>]/g, '_')
    .replace(/[\r\n]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Absolute path for a playlist file inside a library directory. */
export function playlistFilePath(libraryDir, name) {
  const safeName = sanitizePlaylistName(name) || 'playlist';
  return join(libraryDir, `${safeName}.m3u8`);
}

/**
 * Serialise tracks (already in playlist order) to an M3U8 document.
 * @param {string} name playlist display name
 * @param {Array<{ artist?: string, title?: string, path: string }>} tracks
 */
export function buildPlaylistM3U8(name, tracks) {
  const displayName = String(name ?? '').replace(/[\r\n]+/g, ' ').trim();

  const lines = ['#EXTM3U'];
  if (displayName) lines.push(`#PLAYLIST:${displayName}`);
  for (const track of tracks) {
    const artist = track.artist || 'Unknown Artist';
    const title = track.title || 'Unknown Title';
    lines.push(`#EXTINF:-1,${artist} - ${title}`);
    lines.push(track.path);
  }
  return lines.join('\n') + '\n';
}
