/**
 * appleMusic.js — minimal Apple Music catalog client for playlist expansion.
 *
 * MusicLab imports playlists by downloading each song into its *own* album
 * folder (as if the song had been imported on its own) and then re-creating
 * the playlist as an ordered .m3u8. To do that it must first learn the
 * playlist's ordered track list, which amdl does not expose without also
 * downloading the playlist into a flat folder.
 *
 * We therefore read the ordered track list from Apple's public catalog API
 * using the same anonymous web token as the catalog search proxy
 * (see ampToken.js). Only catalog playlists (ids beginning with "pl.") are
 * resolvable this way; personal library playlists (MusicKit "p." ids) require
 * a Music-User-Token and are left to the caller's fallback path.
 */

import { getAnonymousAmpToken } from './ampToken.js';

const AMP_BASE = 'https://amp-api.music.apple.com';
const TRACKS_PAGE_SIZE = 100;
const MAX_PAGES = 500;

function ampHeaders(token) {
  return {
    Authorization: `Bearer ${token}`,
    Origin: 'https://music.apple.com'
  };
}

/**
 * Fetch a catalog playlist's ordered track list (including the playlist name).
 *
 * @param {string} storefront e.g. "us"
 * @param {string} playlistId e.g. "pl.u-76oNlDNIve4AoR2"
 * @param {{ token?: string, fetchImpl?: typeof fetch }} [options]
 * @returns {Promise<{ name: string, tracks: Array<{ id: string, name: string, artistName: string, albumName: string }> }>}
 */
export async function fetchPlaylistTracks(storefront, playlistId, options = {}) {
  const fetchImpl = options.fetchImpl || fetch;
  const token = options.token || await getAnonymousAmpToken();
  const headers = ampHeaders(token);

  const sf = encodeURIComponent(storefront);
  const id = encodeURIComponent(playlistId);

  // Playlist name (used for the .m3u8 filename and #PLAYLIST tag).
  const metaRes = await fetchImpl(`${AMP_BASE}/v1/catalog/${sf}/playlists/${id}`, { headers });
  if (!metaRes.ok) {
    throw new Error(`Apple Music playlist lookup failed (${metaRes.status})`);
  }
  const meta = await metaRes.json();
  const name = meta.data?.[0]?.attributes?.name || '';

  // Ordered tracks, paginated. The response's `next` is a path relative to
  // the amp-api host (e.g. "/v1/catalog/us/playlists/.../tracks?offset=100").
  const tracks = [];
  let next = `${AMP_BASE}/v1/catalog/${sf}/playlists/${id}/tracks?limit=${TRACKS_PAGE_SIZE}`;

  for (let page = 0; next && page < MAX_PAGES; page++) {
    const res = await fetchImpl(next, { headers });
    if (!res.ok) {
      throw new Error(`Apple Music playlist tracks failed (${res.status})`);
    }
    const body = await res.json();
    for (const item of body.data || []) {
      tracks.push({
        id: item.id,
        name: item.attributes?.name || '',
        artistName: item.attributes?.artistName || '',
        albumName: item.attributes?.albumName || ''
      });
    }
    next = body.next ? new URL(body.next, AMP_BASE).toString() : null;
  }

  return { name, tracks };
}

/** Catalog song page URL that amdl accepts for a single-track download. */
export function songUrl(storefront, songId) {
  return `https://music.apple.com/${storefront}/song/${songId}`;
}
