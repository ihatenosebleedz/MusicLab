/**
 * urlParser.js — Apple Music URL validation and parsing.
 *
 * Supported formats:
 * https://music.apple.com/{storefront}/album/{slug}/{id}
 * https://music.apple.com/{storefront}/album/{id}
 * https://music.apple.com/{storefront}/song/{slug}/{id}
 * https://music.apple.com/{storefront}/playlist/{slug}/{id}
 * https://music.apple.com/{storefront}/artist/{slug}/{id}
 * https://music.apple.com/{storefront}/station/{slug}/{id}
 */

export function parseAppleMusicUrl(rawUrl) {
  if (typeof rawUrl !== 'string' || !rawUrl.trim()) {
    return { valid: false, error: 'URL must be a non-empty string' };
  }

  let parsed;
  try {
    parsed = new URL(rawUrl.trim());
  } catch {
    return { valid: false, error: 'Malformed URL' };
  }

  if (parsed.hostname !== 'music.apple.com') {
    return { valid: false, error: 'Expected host music.apple.com' };
  }

  // Path segments: ['', '{storefront}', '{type}', ...rest]
  const segments = parsed.pathname.split('/').filter(Boolean);
  if (segments.length < 2) {
    return { valid: false, error: 'Invalid Apple Music URL path structure' };
  }

  const storefront = segments[0];
  const typeSegment = segments[1];

  const allowedTypes = ['album', 'song', 'playlist', 'artist', 'station'];
  if (!allowedTypes.includes(typeSegment)) {
    return { valid: false, error: `Unsupported item type: ${typeSegment}` };
  }

  // Extract ID (usually last segment or query param ?i= for song in album)
  let id = segments[segments.length - 1];
  let type = typeSegment;

  const songId = parsed.searchParams.get('i');
  if (songId) {
    type = 'song';
    id = songId;
  }

  return {
    valid: true,
    storefront,
    type,
    id,
    cleanUrl: parsed.origin + parsed.pathname + (songId ? `?i=${songId}` : '')
  };
}
