/**
 * server.js — Main express entry point for musiclab-backend.
 */

import express from 'express';
import { config } from './config.js';
import { requireAuth } from './auth.js';
import { healthRouter } from './health.js';
import { jobsRouter } from './jobs.js';
import { logsRouter } from './logs.js';
import { destinationsRouter } from './destinations.js';
import { catalogRouter } from './catalog.js';
import { recoverActiveJobs } from './jobRunner.js';

export function createApp() {
  const app = express();

  app.use(express.json());

  // Public unauthenticated health check
  app.use('/', healthRouter);

  // Authenticated routes
  app.use('/catalog', requireAuth, catalogRouter);
  app.use('/jobs', requireAuth, jobsRouter);
  app.use('/logs', requireAuth, logsRouter);
  app.use('/destinations', requireAuth, destinationsRouter);

  // Fallback 404 handler
  app.use((req, res) => {
    res.status(404).json({
      error: {
        code: 'NOT_FOUND',
        message: `Endpoint ${req.method} ${req.url} does not exist.`
      }
    });
  });

  return app;
}

// Start standalone server if directly invoked
if (process.argv[1]?.endsWith('server.js')) {
  recoverActiveJobs();
  const app = createApp();
  app.listen(config.port, config.host, () => {
    console.log(`[musiclab-backend] listening on ${config.host}:${config.port}`);
  });
}
