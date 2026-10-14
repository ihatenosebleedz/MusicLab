/**
 * health.js — Health probe router.
 */

import { Router } from 'express';
import { existsSync } from 'fs';
import { config } from './config.js';
import { checkNavidromeHealth } from './navidrome.js';

export const healthRouter = Router();

healthRouter.get('/health', async (req, res) => {
  // Check amdl executable
  const amdlAvailable = existsSync(config.amdl.bin) || existsSync(`${config.amdl.cwd}/${config.amdl.bin}`);

  // Check wrapper-lite
  let wrapperLiteHealthy = false;
  let regions = [];
  try {
    const wlRes = await fetch(`${config.wrapperLite.url}/status`, { signal: AbortSignal.timeout(2000) });
    if (wlRes.ok) {
      const data = await wlRes.json();
      wrapperLiteHealthy = true;
      regions = data.regions || ['us'];
    }
  } catch {}

  // Check navidrome
  const navidromeHealthy = await checkNavidromeHealth();

  return res.json({
    status: 'ok',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    services: {
      amdl: {
        path: `${config.amdl.cwd}/${config.amdl.bin}`,
        available: amdlAvailable
      },
      wrapperLite: {
        endpoint: config.wrapperLite.url,
        healthy: wrapperLiteHealthy,
        regions
      },
      navidrome: {
        endpoint: config.navidrome.url,
        musicFolder: config.navidrome.musicFolder,
        openSubsonic: navidromeHealthy
      }
    }
  });
});
