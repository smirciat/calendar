CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS families (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS calendar_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  source_type TEXT NOT NULL DEFAULT 'google',
  google_account_email TEXT,
  refresh_token_encrypted TEXT,
  feed_url TEXT,
  nickname TEXT NOT NULL DEFAULT 'Calendar',
  color TEXT NOT NULL DEFAULT '#4285F4',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_synced_at TIMESTAMPTZ,
  CONSTRAINT calendar_connections_source_check CHECK (
    (source_type = 'google'
      AND google_account_email IS NOT NULL
      AND refresh_token_encrypted IS NOT NULL
      AND feed_url IS NULL)
    OR
    (source_type = 'ics'
      AND feed_url IS NOT NULL
      AND google_account_email IS NULL
      AND refresh_token_encrypted IS NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_calendar_connections_google
  ON calendar_connections (family_id, google_account_email)
  WHERE source_type = 'google';

CREATE UNIQUE INDEX IF NOT EXISTS idx_calendar_connections_ics
  ON calendar_connections (family_id, feed_url)
  WHERE source_type = 'ics';

CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  calendar_connection_id UUID NOT NULL REFERENCES calendar_connections(id) ON DELETE CASCADE,
  google_event_id TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '(no title)',
  description TEXT,
  location TEXT,
  start_at TIMESTAMPTZ NOT NULL,
  end_at TIMESTAMPTZ NOT NULL,
  all_day BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (calendar_connection_id, google_event_id)
);

CREATE INDEX IF NOT EXISTS idx_events_start ON events (start_at);
CREATE INDEX IF NOT EXISTS idx_events_end ON events (end_at);

CREATE TABLE IF NOT EXISTS devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT 'Wall display',
  token_hash TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS pairing_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  code TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pairing_codes_code ON pairing_codes (code);
