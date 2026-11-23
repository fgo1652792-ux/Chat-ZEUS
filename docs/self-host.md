# Self-host Zeus Hub

Zeus Hub uses Node.js 22 and PostgreSQL 17. The Flutter client can
start and keep its local conversation history with no Hub configured.

## Start the service

1. Copy `infra/.env.example` to `infra/.env`. Generate an independent
   database password and registration code with `openssl rand -hex 24`.
2. Run `docker compose --env-file infra/.env -f infra/docker-compose.yml up -d --build`.
3. Visit `http://127.0.0.1:8080/health` to confirm that PostgreSQL is reachable.
4. Expose the Hub through an HTTPS reverse proxy for other devices. Configure
   `HUB_ALLOWED_ORIGINS` with the exact origin of a hosted web client.

Hub migrations run on startup under a database lock. Back up the PostgreSQL
volume using `pg_dump` with the deployment's configured PostgreSQL account.

## Data and jobs

Each record, file, job, and job run is addressed within the authenticated
account. Sessions use short-lived access tokens and rotating refresh tokens.
The server persists token hashes.

The sync API uses a per-account cursor, record versions, and tombstones.
Concurrent writes return the stored record as a conflict for the client to
resolve. The scheduler currently runs workspace summaries on a UTC timestamp
with an optional fixed interval. Job status and output are stored in PostgreSQL.

The Hub accepts selected conversation and project content as clear JSON over
TLS. Provider keys stay with the Flutter client. For registration, use the
invite code in the instance's configuration.

## Tests

Set `TEST_DATABASE_URL` to a PostgreSQL test database, then run `npm ci` and
`npm test` in `services/zeus_hub`. The integration test uses two accounts and
checks sync, conflict handling, account isolation, session rotation, file
access, and persisted job results.
