import { setTimeout as delay } from 'node:timers/promises';
import pg from 'pg';

import { createApp } from './app.js';
import { migrate } from './database.js';
import { runDueJob } from './jobs.js';

const url = process.env.DATABASE_URL;
if (!url) throw new Error('DATABASE_URL is required');

const pool = new pg.Pool({ connectionString: url, max: 8, statement_timeout: 15000 });
await migrate(pool);
const app = await createApp({
  pool,
  registrationCode: process.env.HUB_INVITE_CODE,
  allowedOrigins: (process.env.HUB_ALLOWED_ORIGINS ?? '').split(',').map((s) => s.trim()).filter(Boolean),
});
const abort = new AbortController();
const worker = (async () => {
  while (!abort.signal.aborted) {
    let processed = false;
    try {
      processed = await runDueJob(pool);
    } catch {
      process.stderr.write('Zeus Hub could not claim a scheduled job.\n');
    }
    if (!processed) await delay(3000, undefined, { signal: abort.signal }).catch(() => undefined);
  }
})();
for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.once(signal, () => {
    abort.abort();
    void Promise.all([worker, app.close()]).then(() => pool.end());
  });
}
await app.listen({ host: '0.0.0.0', port: Number(process.env.PORT ?? '8080') });
