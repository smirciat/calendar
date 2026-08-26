-- Idempotent upgrades for databases created before ICS calendar support.

ALTER TABLE calendar_connections
  ADD COLUMN IF NOT EXISTS source_type TEXT NOT NULL DEFAULT 'google';

ALTER TABLE calendar_connections
  ADD COLUMN IF NOT EXISTS feed_url TEXT;

ALTER TABLE calendar_connections
  ALTER COLUMN google_account_email DROP NOT NULL;

ALTER TABLE calendar_connections
  ALTER COLUMN refresh_token_encrypted DROP NOT NULL;

ALTER TABLE calendar_connections
  DROP CONSTRAINT IF EXISTS calendar_connections_family_id_google_account_email_key;

CREATE UNIQUE INDEX IF NOT EXISTS idx_calendar_connections_google
  ON calendar_connections (family_id, google_account_email)
  WHERE source_type = 'google';

CREATE UNIQUE INDEX IF NOT EXISTS idx_calendar_connections_ics
  ON calendar_connections (family_id, feed_url)
  WHERE source_type = 'ics';
