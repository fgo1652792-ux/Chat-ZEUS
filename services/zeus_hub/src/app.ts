import { createHash, randomUUID } from 'node:crypto';
import cors from '@fastify/cors';
import rateLimit from '@fastify/rate-limit';
import Fastify from 'fastify';
import type { FastifyRequest } from 'fastify';
import type { Pool } from 'pg';
import { z } from 'zod';
import { checkPassword, createSession, hashPassword, refreshSession, revokeSession, userForToken } from './auth.js';
import { transaction } from './database.js';

declare module 'fastify' {
  interface FastifyRequest {
    owner: string | null;
  }
}

type AppOptions = {
  pool: Pool;
  registrationCode?: string;
  allowedOrigins?: string[];
};

const uuid = z.uuid();
const idParams = z.object({ id: uuid });
const bearer = /^Bearer ([A-Za-z0-9_-]{43})$/;
const credentials = z.object({
  email: z.email().max(254).transform((s) => s.trim().toLowerCase()),
  password: z.string().min(12).max(1024),
});
const refresh = z.object({ refreshToken: z.string().regex(/^[A-Za-z0-9_-]{43}$/) });
const body = z.strictObject({
  title: z.string().min(1).max(160),
  description: z.string().max(24000).optional(),
  instructions: z.string().max(24000).optional(),
  messages: z.array(z.strictObject({
    role: z.enum(['user', 'assistant', 'system', 'tool']),
    content: z.string().max(120000),
  })).max(500).optional(),
});
const record = z.object({
  id: uuid,
  kind: z.enum(['project', 'conversation', 'settings']),
  version: z.int().nonnegative(),
  deleted: z.boolean().default(false),
  body: body.nullable(),
}).refine((item) => item.deleted ? item.body === null : item.body !== null);
const syncBody = z.object({
  cursor: z.string().regex(/^(0|[1-9][0-9]{0,18})$/).default('0'),
  changes: z.array(record).max(25).default([]),
});
const jobBody = z.object({
  kind: z.literal('workspace_summary'),
  runAt: z.iso.datetime(),
  intervalSeconds: z.int().min(60).max(31536000).optional(),
});
const fileBody = z.object({
  name: z.string().min(1).max(200).regex(/^[^\x00-\x1f/\\]+$/),
  content: z.string().min(4).max(2800000).regex(/^[A-Za-z0-9+/]+={0,2}$/),
  sha256: z.string().regex(/^[a-f0-9]{64}$/),
});

const ownerOf = (request: FastifyRequest) => request.owner!;

export async function createApp(options: AppOptions) {
  const db = options.pool;
  const app = Fastify({ bodyLimit: 3 * 1024 * 1024 });
  app.decorateRequest('owner', null);

  await app.register(cors, {
    origin: options.allowedOrigins ?? [],
    methods: ['GET', 'POST', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });
  await app.register(rateLimit, { max: 150, timeWindow: '1 minute' });

  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof z.ZodError) {
      return reply.code(400).send({ error: 'invalid_request' });
    }
    const numeric = (error as { statusCode?: number }).statusCode;
    const status = numeric && numeric >= 400 && numeric < 500 ? numeric : 500;
    return reply.code(status).send({ error: status === 500 ? 'request_failed' : 'invalid_request' });
  });

  app.get('/health', async () => {
    await db.query('SELECT 1');
    return { status: 'ok' };
  });

  app.post('/v1/auth/register', { config: { rateLimit: { max: 12, timeWindow: '1 minute' } } }, async (request, reply) => {
    const input = credentials.extend({ inviteCode: z.string().max(256) }).parse(request.body);
    if (!options.registrationCode || input.inviteCode !== options.registrationCode) {
      return reply.code(403).send({ error: 'registration_closed' });
    }
    const hash = await hashPassword(input.password);
    const result = await transaction(db, async (client) => {
      const id = randomUUID();
      const inserted = await client.query(
        'INSERT INTO hub_users (id, email, password_hash) VALUES ($1, $2, $3) ON CONFLICT (email) DO NOTHING',
        [id, input.email, hash],
      );
      return inserted.rowCount ? createSession(client, id) : null;
    });
    return result ? reply.code(201).send(result) : reply.code(409).send({ error: 'account_exists' });
  });

  app.post('/v1/auth/login', { config: { rateLimit: { max: 12, timeWindow: '1 minute' } } }, async (request, reply) => {
    const input = credentials.parse(request.body);
    const result = await db.query('SELECT id, password_hash FROM hub_users WHERE email = $1', [input.email]);
    const row = result.rows[0];
    if (!await checkPassword(input.password, row?.password_hash)) {
      return reply.code(401).send({ error: 'invalid_credentials' });
    }
    return createSession(db, row.id);
  });

  app.post('/v1/auth/refresh', async (request, reply) => {
    const { refreshToken } = refresh.parse(request.body);
    const tokens = await refreshSession(db, refreshToken);
    return tokens ?? reply.code(401).send({ error: 'invalid_session' });
  });

  app.post('/v1/auth/logout', async (request, reply) => {
    const { refreshToken } = refresh.parse(request.body);
    await revokeSession(db, refreshToken);
    return reply.code(204).send();
  });

  await app.register(async (authenticated) => {
    authenticated.addHook('preHandler', async (request, reply) => {
      const token = bearer.exec(request.headers.authorization ?? '')?.[1];
      const owner = token && await userForToken(db, token);
      if (!owner) return reply.code(401).send({ error: 'invalid_session' });
      request.owner = owner;
    });

    authenticated.delete('/v1/account', async (request, reply) => {
      await db.query('DELETE FROM hub_users WHERE id = $1', [ownerOf(request)]);
      return reply.code(204).send();
    });

    authenticated.get('/v1/projects', async (request) => {
      const rows = await db.query(
        `SELECT id, version, cursor, body, updated_at FROM hub_records
          WHERE owner = $1 AND kind = 'project' AND deleted = false ORDER BY cursor DESC LIMIT 100`,
        [ownerOf(request)],
      );
      return { projects: rows.rows };
    });

    authenticated.post('/v1/sync/batch', async (request) => {
      const input = syncBody.parse(request.body);
      const owner = ownerOf(request);
      return transaction(db, async (client) => {
        const locked = await client.query('SELECT id FROM hub_users WHERE id = $1 FOR UPDATE', [owner]);
        if (locked.rowCount !== 1) throw new Error('account expired');
        const applied = [];
        const conflicts = [];
        for (const change of input.changes) {
          const { id, kind, deleted, body: data, version } = change;
          const existing = await client.query(
            'SELECT id, kind, version, cursor, body, deleted FROM hub_records WHERE owner = $1 AND kind = $2 AND id = $3',
            [owner, kind, id],
          );
          const remote = existing.rows[0];
          if ((remote?.version ?? 0) !== version) {
            conflicts.push({ id, kind, current: remote ?? null });
            continue;
          }
          const next = await client.query(
            'UPDATE hub_users SET sync_cursor = sync_cursor + 1 WHERE id = $1 RETURNING sync_cursor',
            [owner],
          );
          const cursor = next.rows[0].sync_cursor as string;
          const result = await client.query(
            `INSERT INTO hub_records (owner, kind, id, version, cursor, body, deleted)
              VALUES ($1, $2, $3, $4, $5, $6, $7)
              ON CONFLICT (owner, kind, id) DO UPDATE SET
                version = EXCLUDED.version, cursor = EXCLUDED.cursor, body = EXCLUDED.body, deleted = EXCLUDED.deleted, updated_at = now()
              RETURNING id, kind, version, cursor`,
            [owner, kind, id, version + 1, cursor, data, deleted],
          );
          applied.push(result.rows[0]);
        }
        const updated = await client.query(
          `SELECT id, kind, version, cursor, body, deleted FROM hub_records
            WHERE owner = $1 AND cursor > $2 ORDER BY cursor LIMIT 100`,
          [owner, input.cursor],
        );
        return {
          applied,
          conflicts,
          changes: updated.rows,
          cursor: updated.rows.at(-1)?.cursor ?? input.cursor,
          more: updated.rows.length === 100,
        };
      });
    });

    authenticated.get('/v1/jobs', async (request) => {
      const data = await db.query(
        `SELECT id, kind, state, next_run_at, interval_seconds, attempts, created_at
          FROM hub_jobs WHERE owner = $1 ORDER BY created_at DESC LIMIT 100`,
        [ownerOf(request)],
      );
      return { jobs: data.rows };
    });

    authenticated.post('/v1/jobs', async (request, reply) => {
      const input = jobBody.parse(request.body);
      const id = randomUUID();
      await db.query(
        `INSERT INTO hub_jobs (id, owner, kind, state, next_run_at, interval_seconds)
          VALUES ($1, $2, $3, 'queued', $4, $5)`,
        [id, ownerOf(request), input.kind, input.runAt, input.intervalSeconds ?? null],
      );
      return reply.code(201).send({ id, state: 'queued' });
    });

    authenticated.get('/v1/jobs/:id/runs', async (request, reply) => {
      const { id } = idParams.parse(request.params);
      const result = await db.query(
        'SELECT id FROM hub_jobs WHERE owner = $1 AND id = $2',
        [ownerOf(request), id],
      );
      if (!result.rowCount) return reply.code(404).send({ error: 'not_found' });
      const runs = await db.query(
        `SELECT r.id, r.started_at, r.completed_at, r.result FROM hub_job_results r
          JOIN hub_jobs j ON r.job_id = j.id WHERE j.owner = $1 AND j.id = $2 ORDER BY r.completed_at DESC LIMIT 50`,
        [ownerOf(request), id],
      );
      return { runs: runs.rows };
    });

    authenticated.post('/v1/jobs/:id/cancel', async (request, reply) => {
      const { id } = idParams.parse(request.params);
      const result = await db.query(
        `UPDATE hub_jobs SET state = 'cancelled', lease_token = NULL, lease_until = NULL
          WHERE owner = $1 AND id = $2 AND state IN ('queued', 'running')`,
        [ownerOf(request), id],
      );
      return result.rowCount ? { state: 'cancelled' } : reply.code(404).send({ error: 'not_found' });
    });

    authenticated.post('/v1/files', async (request, reply) => {
      const input = fileBody.parse(request.body);
      const contents = Buffer.from(input.content, 'base64');
      const sha = createHash('sha256').update(contents).digest('hex');
      if (contents.length === 0 || contents.length > 2 * 1024 * 1024 || sha !== input.sha256) {
        return reply.code(422).send({ error: 'invalid_file' });
      }
      const id = randomUUID();
      await db.query('INSERT INTO hub_files (id, owner, name, size, sha256, contents) VALUES ($1, $2, $3, $4, $5, $6)',
        [id, ownerOf(request), input.name, contents.length, sha, contents]);
      return reply.code(201).send({ id, sha256: sha, size: contents.length });
    });

    authenticated.get('/v1/files/:id', async (request, reply) => {
      const { id } = idParams.parse(request.params);
      const result = await db.query('SELECT name, contents FROM hub_files WHERE owner = $1 AND id = $2', [ownerOf(request), id]);
      if (!result.rowCount) return reply.code(404).send({ error: 'not_found' });
      const file = result.rows[0];
      return reply.type('application/octet-stream')
        .header('Content-Disposition', "attachment; filename*=UTF-8''" + encodeURIComponent(file.name))
        .header('X-Content-Type-Options', 'nosniff')
        .send(file.contents);
    });
  });

  return app;
}
