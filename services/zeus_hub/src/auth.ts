import { createHash, randomBytes, randomUUID, scrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import type { Pool, PoolClient } from 'pg';
import { transaction } from './database.js';

const derive = promisify(scrypt);
const fallback = '00000000000000000000000000000000:' + '0'.repeat(128);
type Queryable = Pool | PoolClient;

function digest(secret: string) {
  return createHash('sha256').update(secret).digest('hex');
}

export async function hashPassword(password: string) {
  const salt = randomBytes(16).toString('hex');
  const key = await derive(password, salt, 64) as Buffer;
  return salt + ':' + key.toString('hex');
}

export async function checkPassword(password: string, stored: string | undefined) {
  const [salt, value] = (stored ?? fallback).split(':');
  const actual = await derive(password, salt, 64) as Buffer;
  return Boolean(stored) && timingSafeEqual(actual, Buffer.from(value, 'hex'));
}

export function issuedTokens() {
  const accessToken = randomBytes(32).toString('base64url');
  const refreshToken = randomBytes(32).toString('base64url');
  return { accessToken, refreshToken, expiresIn: 900 };
}

export async function createSession(db: Queryable, owner: string) {
  const tokens = issuedTokens();
  await db.query(
    `INSERT INTO hub_sessions (id, owner, access_hash, refresh_hash, access_expires, refresh_expires)
      VALUES ($1, $2, $3, $4, now() + interval '15 min', now() + interval '30 days')`,
    [randomUUID(), owner, digest(tokens.accessToken), digest(tokens.refreshToken)],
  );
  return tokens;
}

export async function refreshSession(db: Pool, refreshToken: string) {
  return transaction(db, async (client) => {
    const used = await client.query(
      `DELETE FROM hub_sessions WHERE refresh_hash = $1 AND refresh_expires > now()
        RETURNING owner`,
      [digest(refreshToken)],
    );
    return used.rowCount === 1 ? createSession(client, used.rows[0].owner) : null;
  });
}

export async function userForToken(db: Pool, accessToken: string) {
  const result = await db.query(
    `SELECT owner FROM hub_sessions WHERE access_hash = $1 AND access_expires > now()`,
    [digest(accessToken)],
  );
  return result.rows[0]?.owner as string | undefined;
}

export async function revokeSession(db: Pool, refreshToken: string) {
  await db.query('DELETE FROM hub_sessions WHERE refresh_hash = $1', [digest(refreshToken)]);
}
