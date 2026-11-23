import { readdir, readFile } from 'node:fs/promises';
import type { Pool, PoolClient } from 'pg';

export async function transaction<T>(pool: Pool, work: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await work(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function migrate(pool: Pool) {
  const directory = new URL('../../migrations/', import.meta.url);
  const migrations = (await readdir(directory)).filter((name) => /^\d+_.+\.sql$/.test(name)).sort();
  await transaction(pool, async (db) => {
    await db.query('SELECT pg_advisory_xact_lock(1974592481)');
    await db.query('CREATE TABLE IF NOT EXISTS hub_migrations (name text PRIMARY KEY)');
    const deployed = new Set((await db.query('SELECT name FROM hub_migrations')).rows.map((row) => row.name));
    for (const name of migrations) {
      if (deployed.has(name)) continue;
      await db.query(await readFile(new URL(name, directory), 'utf8'));
      await db.query('INSERT INTO hub_migrations (name) VALUES ($1)', [name]);
    }
  });
}
