/**
 * jobs.js — Import jobs routes.
 */

import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { parseAppleMusicUrl } from './urlParser.js';
import { insertJob, getJob, getActiveJobByUrl, listJobs } from './db.js';
import { enqueueJob, cancelJob } from './jobRunner.js';

export const jobsRouter = Router();

// POST /jobs — Submit import job
jobsRouter.post('/', (req, res) => {
  const { url, name } = req.body || {};

  const parsed = parseAppleMusicUrl(url);
  if (!parsed.valid) {
    return res.status(400).json({
      error: {
        code: 'INVALID_URL',
        message: 'The provided URL is not a valid Apple Music catalog link.',
        details: parsed.error
      }
    });
  }

  // Deduplication / active job check
  const activeExisting = getActiveJobByUrl(parsed.cleanUrl);
  if (activeExisting) {
    return res.status(409).json({
      error: {
        code: 'JOB_ALREADY_ACTIVE',
        message: 'An import job for this item is already active.',
        details: activeExisting
      }
    });
  }

  const id = uuidv4();
  const now = new Date().toISOString();
  const jobRecord = {
    id,
    type: parsed.type,
    url: parsed.cleanUrl,
    name: name?.trim() || `${parsed.type} import (${parsed.id})`,
    state: 'queued',
    stage: 'resolving',
    progress_hint: 'Job enqueued',
    created_at: now,
    updated_at: now
  };

  insertJob(jobRecord);
  enqueueJob(id);

  const created = getJob(id);
  return res.status(201).json(created);
});

// GET /jobs — List import jobs
jobsRouter.get('/', (req, res) => {
  const { status = 'all', limit = '50' } = req.query;
  const parsedLimit = Math.min(Math.max(parseInt(limit, 10) || 50, 1), 100);
  const jobs = listJobs(status, parsedLimit);
  return res.json({ jobs });
});

// GET /jobs/:id — Inspect single job
jobsRouter.get('/:id', (req, res) => {
  const job = getJob(req.params.id);
  if (!job) {
    return res.status(404).json({
      error: {
        code: 'JOB_NOT_FOUND',
        message: `Job ${req.params.id} does not exist.`
      }
    });
  }
  return res.json(job);
});

// POST /jobs/:id/cancel — Cancel active job
jobsRouter.post('/:id/cancel', (req, res) => {
  const job = getJob(req.params.id);
  if (!job) {
    return res.status(404).json({
      error: {
        code: 'JOB_NOT_FOUND',
        message: `Job ${req.params.id} does not exist.`
      }
    });
  }

  const activeStates = ['queued', 'resolving', 'downloading', 'processing', 'waiting_for_navidrome', 'verifying'];
  if (!activeStates.includes(job.state)) {
    return res.status(400).json({
      error: {
        code: 'CANNOT_CANCEL',
        message: `Job ${job.id} is in state "${job.state}" and cannot be cancelled.`
      }
    });
  }

  cancelJob(job.id);

  return res.json({
    id: job.id,
    state: 'cancelled',
    cancelledAt: new Date().toISOString()
  });
});
