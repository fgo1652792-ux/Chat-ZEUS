import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { transaction } from './database.js';

export async function runDueJob(pool: Pool): Promise<boolean> {
  const lease = randomUUID();
  const claim = await pool.query(
    `UPDATE hub_jobs SET state = 'running', lease_token = $1, lease_until = now() + interval '2 min'
      WHERE id = (SELECT id FROM hub_jobs
        WHERE (state = 'queued' AND next_run_at <= now()) OR (state = 'running' AND lease_until < now())
        ORDER BY next_run_at FOR UPDATE SKIP LOCKED LIMIT 1)
      RETURNING id, owner, next_run_at, interval_seconds`,
    [lease],
  );
  const job = claim.rows[0];
  if (!job) return false;
  const startedAt = new Date();
  try {
    await transaction(pool, async (client) => {
      const counts = await client.query(
        'SELECT kind, COUNT(*)::int AS count FROM hub_records WHERE owner = $1 AND deleted = false GROUP BY kind',
        [job.owner],
      );
      const result = Object.fromEntries(counts.rows.map((row) => [row.kind, row.count]));
      const completed = await client.query(
        `UPDATE hub_jobs SET state = CASE WHEN interval_seconds IS NULL THEN 'complete' ELSE 'queued' END,
            next_run_at = CASE WHEN interval_seconds IS NULL THEN next_run_at ELSE now() + make_interval(secs => interval_seconds) END,
            lease_token = NULL, lease_until = NULL, attempts = 0
          WHERE id = $1 AND owner = $2 AND lease_token = $3 AND state = 'running'`,
        [job.id, job.owner, lease],
      );
      if (completed.rowCount === 1) {
        await client.query(
          'INSERT INTO hub_job_results (id, job_id, started_at, result) VALUES ($1, $2, $3, $4)',
          [randomUUID(), job.id, startedAt, { recordCounts: result }],
        );
      }
    });
  } catch {
    await pool.query(
      `UPDATE hub_jobs SET attempts = attempts + 1,
          state = CASE WHEN attempts < 2 THEN 'queued' ELSE 'failed' END,
          next_run_at = now() + make_interval(secs => 20 * (attempts + 1)),
          lease_token = NULL, lease_until = NULL
        WHERE id = $1 AND owner = $2 AND lease_token = $3`,
      [job.id, job.owner, lease],
    );
  }
  return true;
}
