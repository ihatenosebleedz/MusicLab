/**
 * catalog.js — Apple Music catalog proxy routes.
 */

import { Router } from 'express';
import { getAnonymousAmpToken } from './ampToken.js';

export const catalogRouter = Router();

catalogRouter.get('/search', async (req, res) => {
  const { term, types = 'albums,songs,playlists,artists', storefront = 'us', limit = '20' } = req.query;

  if (!term || typeof term !== 'string' || !term.trim()) {
    return res.status(400).json({
      error: {
        code: 'INVALID_REQUEST',
        message: 'Search parameter "term" is required.'
      }
    });
  }

  const parsedLimit = Math.min(Math.max(parseInt(limit, 10) || 20, 1), 50);

  try {
    const token = await getAnonymousAmpToken();
    const ampUrl = new URL(`https://amp-api.music.apple.com/v1/catalog/${encodeURIComponent(storefront)}/search`);
    ampUrl.searchParams.set('term', term.trim());
    ampUrl.searchParams.set('types', types);
    ampUrl.searchParams.set('limit', String(parsedLimit));

    const response = await fetch(ampUrl.toString(), {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Origin': 'https://music.apple.com'
      }
    });

    if (!response.ok) {
      const errText = await response.text();
      return res.status(response.status).json({
        error: {
          code: 'UPSTREAM_ERROR',
          message: `Apple Music API error: ${response.status}`,
          details: errText
        }
      });
    }

    const data = await response.json();
    const results = {
      albums: [],
      songs: [],
      playlists: [],
      artists: []
    };

    if (data.results?.albums?.data) {
      results.albums = data.results.albums.data.map(item => ({
        id: item.id,
        type: 'album',
        title: item.attributes?.name || '',
        artistName: item.attributes?.artistName || '',
        releaseDate: item.attributes?.releaseDate || '',
        artworkUrl: item.attributes?.artwork?.url
          ? item.attributes.artwork.url.replace('{w}', '600').replace('{h}', '600')
          : '',
        trackCount: item.attributes?.trackCount || 0,
        appleMusicUrl: item.attributes?.url || `https://music.apple.com/${storefront}/album/${item.id}`,
        genre: item.attributes?.genreNames?.[0] || ''
      }));
    }

    if (data.results?.songs?.data) {
      results.songs = data.results.songs.data.map(item => ({
        id: item.id,
        type: 'song',
        title: item.attributes?.name || '',
        artistName: item.attributes?.artistName || '',
        releaseDate: item.attributes?.releaseDate || '',
        artworkUrl: item.attributes?.artwork?.url
          ? item.attributes.artwork.url.replace('{w}', '600').replace('{h}', '600')
          : '',
        albumName: item.attributes?.albumName || '',
        appleMusicUrl: item.attributes?.url || `https://music.apple.com/${storefront}/song/${item.id}`,
        durationInMillis: item.attributes?.durationInMillis || 0
      }));
    }

    if (data.results?.playlists?.data) {
      results.playlists = data.results.playlists.data.map(item => ({
        id: item.id,
        type: 'playlist',
        title: item.attributes?.name || '',
        artistName: item.attributes?.curatorName || '',
        releaseDate: item.attributes?.releaseDate || '',
        artworkUrl: item.attributes?.artwork?.url
          ? item.attributes.artwork.url.replace('{w}', '600').replace('{h}', '600')
          : '',
        trackCount: item.attributes?.trackCount || 0,
        appleMusicUrl: item.attributes?.url || `https://music.apple.com/${storefront}/playlist/${item.id}`,
        genre: item.attributes?.genreNames?.[0] || ''
      }));
    }

    if (data.results?.artists?.data) {
      results.artists = data.results.artists.data.map(item => ({
        id: item.id,
        type: 'artist',
        title: item.attributes?.name || '',
        artistName: item.attributes?.artistName || '',
        artworkUrl: item.attributes?.artwork?.url
          ? item.attributes.artwork.url.replace('{w}', '600').replace('{h}', '600')
          : '',
        appleMusicUrl: item.attributes?.url || `https://music.apple.com/${storefront}/artist/${item.id}`,
        genre: item.attributes?.genreNames?.[0] || ''
      }));
    }

    return res.json({ results });
  } catch (err) {
    return res.status(500).json({
      error: {
        code: 'CATALOG_PROXY_ERROR',
        message: err.message
      }
    });
  }
});