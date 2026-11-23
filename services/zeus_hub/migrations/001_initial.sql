CREATE TABLE hub_users (
  id uuid PRIMARY KEY,
  email text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  sync_cursor bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE hub_sessions (
  id uuid PRIMARY KEY,
  owner uuid NOT NULL REFERENCES hub_users(id) ON DELETE CASCADE,
  access_hash text NOT NULL UNIQUE,
  refresh_hash text NOT NULL UNIQUE,
  access_expires timestamptz NOT NULL,
  refresh_expires timestamptz NOT NULL
);
CREATE INDEX hub_sessions_expiration ON hub_sessions(refresh_expires);
CREATE TABLE hub_records (
  owner uuid NOT NULL REFERENCES hub_users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('project', 'conversation', 'settings')),
  id uuid NOT NULL,
  version integer NOT NULL CHECK (version > 0),
  cursor bigint NOT NULL,
  body jsonb,
  deleted boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (owner, kind, id),
  UNIQUE (owner, cursor)
);
CREATE TABLE hub_jobs (
  id uuid PRIMARY KEY,
  owner uuid NOT NULL REFERENCES hub_users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('workspace_summary')),
  state text NOT NULL CHECK (state IN ('queued', 'running', 'complete', 'failed', 'cancelled')),
  next_run_at timestamptz NOT NULL,
  interval_seconds integer CHECK (interval_seconds >= 60),
  attempts integer NOT NULL DEFAULT 0,
  lease_until timestamptz,
  lease_token uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX hub_jobs_due ON hub_jobs(state, next_run_at);
CREATE INDEX hub_jobs_owner ON hub_jobs(owner, created_at DESC);
CREATE TABLE hub_job_results (
  id uuid PRIMARY KEY,
  job_id uuid NOT NULL REFERENCES hub_jobs(id) ON DELETE CASCADE,
  started_at timestamptz NOT NULL,
  completed_at timestamptz NOT NULL DEFAULT now(),
  result jsonb NOT NULL
);
CREATE TABLE hub_files (
  id uuid PRIMARY KEY,
  owner uuid NOT NULL REFERENCES hub_users(id) ON DELETE CASCADE,
  name text NOT NULL,
  size integer NOT NULL CHECK (size > 0),
  sha256 text NOT NULL,
  contents bytea NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
