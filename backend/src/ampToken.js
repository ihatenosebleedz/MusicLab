/**
 * ampToken.js — Anonymous Apple Music token fetching & caching.
 */

let cachedToken = null;
let tokenExpiresAt = 0;

export async function getAnonymousAmpToken() {
  const now = Date.now();
  if (cachedToken && now < tokenExpiresAt) {
    return cachedToken;
  }

  // Scrape music.apple.com to obtain index JS bundle containing developerToken
  try {
    const res = await fetch('https://music.apple.com/us/browse', {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15'
      }
    });
    if (!res.ok) {
      throw new Error(`Failed to load music.apple.com: ${res.status}`);
    }
    const html = await res.text();

    // Look for script tags: /assets/index~...js or index-*.js
    const scriptMatches = [...html.matchAll(/src="([^"]*(?:\/assets\/index~|index)[^"]*\.js)"/g)];
    for (const match of scriptMatches) {
      let scriptUrl = match[1];
      if (scriptUrl.startsWith('/')) {
        scriptUrl = `https://music.apple.com${scriptUrl}`;
      }

      const scriptRes = await fetch(scriptUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'
        }
      });
      if (!scriptRes.ok) continue;
      const scriptBody = await scriptRes.text();

      // Look for jwt token pattern: eyJ...
      const tokenMatch = scriptBody.match(/(eyJ[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+)/);
      if (tokenMatch) {
        cachedToken = tokenMatch[1];
        tokenExpiresAt = now + 12 * 60 * 60 * 1000; // Cache for 12 hours
        return cachedToken;
      }
    }
  } catch (err) {
    console.warn('[ampToken] Failed to fetch anonymous token dynamically:', err.message);
  }

  // Fallback fallback / hardcoded or cached if available
  if (cachedToken) {
    return cachedToken;
  }
  throw new Error('Could not resolve Apple Music Web token');
}
