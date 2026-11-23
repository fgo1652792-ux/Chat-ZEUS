import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import test from 'node:test';
import pg from 'pg';

import { createApp } from '../src/app.js';
import { migrate } from '../src/database.js';
import { runDueJob } from '../src/jobs.js';

const databaseUrl = process.env.TEST_DATABASE_URL;

test('authenticated sync, file isolation, token rotation and persistent jobs', {
  skip: !databaseUrl,
}, async (t) => {
  const pool = new pg.Pool({ connectionString: databaseUrl });
  t.after(() => pool.end());
  await migrate(pool);
  const inviteCode = 'integration-fixture';
  const app = await createApp({ pool, registrationCode: inviteCode });
  t.after(() => app.close());

  const register = async (name: string) => {
    const response = await app.inject({
      method: 'POST', url: '/v1/auth/register',
      payload: {
        email: `${name}+${randomUUID()}@example.test`,
        password: 'fixture-password-only',
        inviteCode,
      },
    });
    assert.equal(response.statusCode, 201, response.body);
    return response.json<{ accessToken: string; refreshToken: string }>();
  };

  const first = await register('first');
  const second = await register('second');
  const header = (token: string) => ({ authorization: 'Bearer ' + token });
  const id = randomUUID();
  const change = { id, kind: 'project', version: 0, body: { title: 'My project' } };

  const initial = await app.inject({
    method: 'POST', url: '/v1/sync/batch', headers: header(first.accessToken),
    payload: { changes: [change] },
  });
  assert.equal(initial.statusCode, 200, initial.body);
  assert.equal(initial.json().applied[0].version, 1);
  assert.equal(initial.json().changes[0].body.title, 'My project');

  const foreign = await app.inject({
    method: 'POST', url: '/v1/sync/batch', headers: header(second.accessToken), payload: {},
  });
  assert.equal(foreign.statusCode, 200);
  assert.deepEqual(foreign.json().changes, []);

  const conflict = await app.inject({
    method: 'POST', url: '/v1/sync/batch', headers: header(first.accessToken),
    payload: { cursor: initial.json().cursor, changes: [change] },
  });
  assert.equal(conflict.json().conflicts[0].current.version, 1);
  assert.deepEqual(conflict.json().changes, []);

  const bytes = Buffer.from('owned fixture');
  const uploaded = await app.inject({
    method: 'POST', url: '/v1/files', headers: header(first.accessToken),
    payload: {
      name: 'document.txt',
      content: bytes.toString('base64'),
      sha256: createHash('sha256').update(bytes).digest('hex'),
    },
  });
  assert.equal(uploaded.statusCode, 201, uploaded.body);
  const path = '/v1/files/' + uploaded.json().id;
  assert.equal((await app.inject({ url: path, headers: header(second.accessToken) })).statusCode, 404);
  assert.equal((await app.inject({ url: path, headers: header(first.accessToken) })).body, bytes.toString());

  const job = await app.inject({
    method: 'POST', url: '/v1/jobs', headers: header(first.accessToken),
    payload: { kind: 'workspace_summary', runAt: new Date(Date.now() - 1000).toISOString() },
  });
  assert.equal(job.statusCode, 201, job.body);
  assert.equal(await runDueJob(pool), true);
  const runs = '/v1/jobs/' + job.json().id + '/runs';
  assert.equal((await app.inject({ url: runs, headers: header(second.accessToken) })).statusCode, 404);
  const result = await app.inject({ url: runs, headers: header(first.accessToken) });
  assert.deepEqual(result.json().runs[0].result, { recordCounts: { project: 1 } });

  const renewed = await app.inject({
    method: 'POST', url: '/v1/auth/refresh', payload: { refreshToken: first.refreshToken },
  });
  assert.equal(renewed.statusCode, 200);
  assert.equal((await app.inject({ url: '/v1/projects', headers: header(first.accessToken) })).statusCode, 401);
  assert.equal((await app.inject({
    method: 'POST', url: '/v1/auth/refresh', payload: { refreshToken: first.refreshToken },
  })).statusCode, 401);
  assert.equal((await app.inject({ url: '/v1/projects', headers: header(renewed.json().accessToken) })).statusCode, 200);
});
