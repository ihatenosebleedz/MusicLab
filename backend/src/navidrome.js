/**
 * navidrome.js — Navidrome OpenSubsonic verification and checking.
 */

import { existsSync } from 'fs';
import { createHash, randomBytes } from 'crypto';
import { config } from './config.js';

function getSubsonicAuthParams(user, pass) {
  if (config.navidrome.token && config.navidrome.salt && config.navidrome.user) {
    return {
      u: config.navidrome.user,
      t: config.navidrome.token,
      s: config.navidrome.salt,
      v: '1.16.1',
      c: 'musiclab',
      f: 'json'
    };
  }
  if (!user || !pass) return null;
  const salt = randomBytes(6).toString('hex');
  const token = createHash('md5').update(pass + salt).digest('hex');
  return { u: user, t: token, s: salt, v: '1.16.1', c: 'musiclab', f: 'json' };
}

export async function checkNavidromeHealth() {
  try {
    const auth = getSubsonicAuthParams(config.navidrome.user, config.navidrome.pass);
    const url = new URL(`${config.navidrome.url}/rest/ping.view`);
    if (auth) {
      Object.entries(auth).forEach(([k, v]) => url.searchParams.set(k, v));
    }
    const res = await fetch(url.toString(), { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return false;
    const json = await res.json();
    return json['subsonic-response']?.status === 'ok';
  } catch {
    return false;
  }
}

/**
 * Searches Navidrome using OpenSubsonic search3.view
 */
export async function searchNavidromeSong(title) {
  const auth = getSubsonicAuthParams(config.navidrome.user, config.navidrome.pass);
  if (!auth) return false;

  const url = new URL(`${config.navidrome.url}/rest/search3.view`);
  Object.entries(auth).forEach(([k, v]) => url.searchParams.set(k, v));
  url.searchParams.set('query', title);

  try {
    const res = await fetch(url.toString(), { signal: AbortSignal.timeout(4000) });
    if (!res.ok) return false;
    const data = await res.json();
    const songList = data['subsonic-response']?.searchResult3?.song || [];
    return songList.some(s => s.title?.toLowerCase() === title.toLowerCase());
  } catch {
    return false;
  }
}

/**
 * Verifies tracks on filesystem and then via OpenSubsonic backoff.
 */
export async function verifyTracks(tracks, onProgress, options = {}) {
  // 1. Filesystem check
  let fsVerified = true;
  for (const track of tracks) {
    if (track.path && !existsSync(track.path)) {
      fsVerified = false;
    }
  }

  // If Navidrome is not configured or in test mode, return filesystem verification immediately
  if (!config.navidrome.user || !config.navidrome.pass || options.fast) {
    return { verified: false, matches: 0, fsVerified };
  }

  // 2. OpenSubsonic backoff: t = 2s, 4s, 8s, 16s, 32s, 64s, 120s
  const schedule = [2000, 4000, 8000, 16000, 32000, 64000];
  let matches = 0;
  let attempt = 0;

  for (const delay of schedule) {
    attempt++;
    if (onProgress) {
      onProgress({
        stage: 'verifying',
        progressHint: `Waiting for Navidrome auto-discovery (attempt ${attempt}/${schedule.length + 1})`
      });
    }

    await new Promise(r => setTimeout(r, delay));

    let matchedAll = true;
    let currentMatches = 0;
    for (const track of tracks) {
      const found = await searchNavidromeSong(track.title);
      if (found) {
        currentMatches++;
      } else {
        matchedAll = false;
      }
    }

    matches = currentMatches;
    if (matchedAll && tracks.length > 0) {
      return { verified: true, matches, fsVerified };
    }
  }

  return { verified: matches === tracks.length && tracks.length > 0, matches, fsVerified };
}
