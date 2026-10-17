/**
 * destinations.js — exposes the server-side destination id → path map.
 *
 * The app only ever sees opaque ids; filesystem paths stay server-side
 * (clients cannot choose an arbitrary path).
 */

import { Router } from 'express';
import { config } from './config.js';

export const destinationsRouter = Router();

/**
 * GET /destinations → { destinations: [{ id, isDefault }], defaultId }
 * Paths are intentionally omitted from the response — ids are the contract.
 */
destinationsRouter.get('/', (req, res) => {
  const destinations = Object.keys(config.destinations.map).map((id) => ({
    id,
    isDefault: id === config.destinations.defaultId
  }));

  return res.json({
    destinations,
    defaultId: config.destinations.defaultId || null
  });
});

/**
 * Resolve a requested destination id to its absolute path.
 *
 * - empty/undefined id → configured default (or null when unconfigured)
 * - unknown id → throws a caller-readable error
 * @returns {{ id: string, path: string|null }}
 */
export function resolveDestination(requestedId) {
  const { map, defaultId } = config.destinations;
  const id = (requestedId ?? '').toString().trim() || defaultId;
  if (!id) return { id: '', path: null };
  const path = map[id];
  if (!path) {
    const err = new Error(`Unknown destination "${id}". Known ids: ${Object.keys(map).join(', ') || 'none'}.`);
    err.code = 'INVALID_DESTINATION';
    throw err;
  }
  return { id, path };
}
