import { google } from 'googleapis';
import { Router } from 'express';
import { config, googleOAuthConfigured } from '../config.js';
import { pool } from '../db/pool.js';
import { requireFamilyAuth } from '../middleware/auth.js';
import { decrypt, encrypt } from '../services/crypto.js';
import { isRevokedGoogleTokenError } from '../services/syncErrors.js';
import { parseGoogleEventRange } from '../utils/eventTime.js';
import {
  listIcsEventsForConnection,
  scheduleIcsSync,
  validateIcsFeedUrl,
} from '../services/icsSync.js';

export const calendarsRouter = Router();

const CALENDAR_COLUMNS =
  'id, source_type, google_account_email, feed_url, nickname, color, created_at, last_synced_at';

function oauthClient() {
  return new google.auth.OAuth2(
    config.google.clientId,
    config.google.clientSecret,
    config.google.redirectUri,
  );
}

const SCOPES = [
  'https://www.googleapis.com/auth/calendar.readonly',
  'https://www.googleapis.com/auth/userinfo.email',
];

const CALENDAR_COLORS = [
  '#4285F4',
  '#EA4335',
  '#34A853',
  '#FBBC04',
  '#AB47BC',
  '#FF6D00',
  '#00897B',
  '#E91E63',
];

async function defaultColorForFamily(familyId: string): Promise<string> {
  const result = await pool.query<{ count: string }>(
    'SELECT COUNT(*)::text AS count FROM calendar_connections WHERE family_id = $1',
    [familyId],
  );
  const count = Number(result.rows[0]?.count ?? 0);
  return CALENDAR_COLORS[count % CALENDAR_COLORS.length];
}

calendarsRouter.get('/', requireFamilyAuth, async (req, res) => {
  const result = await pool.query(
    `SELECT ${CALENDAR_COLUMNS}
     FROM calendar_connections
     WHERE family_id = $1
     ORDER BY created_at ASC`,
    [req.auth!.familyId],
  );
  res.json(result.rows);
});

calendarsRouter.post('/ics', requireFamilyAuth, async (req, res) => {
  const { feedUrl, nickname } = req.body as {
    feedUrl?: string;
    nickname?: string;
  };

  if (!feedUrl || feedUrl.trim() === '') {
    res.status(400).json({ error: 'Calendar sync link is required' });
    return;
  }

  let normalizedUrl: string;
  try {
    normalizedUrl = validateIcsFeedUrl(feedUrl);
  } catch (error) {
    res.status(400).json({
      error: error instanceof Error ? error.message : 'Invalid calendar sync link',
    });
    return;
  }

  const trimmedNickname = nickname?.trim();
  if (trimmedNickname !== undefined && trimmedNickname === '') {
    res.status(400).json({ error: 'Nickname cannot be empty' });
    return;
  }

  const familyId = req.auth!.familyId;
  const existing = await pool.query<{ id: string }>(
    `SELECT id FROM calendar_connections
     WHERE family_id = $1 AND source_type = 'ics' AND feed_url = $2`,
    [familyId, normalizedUrl],
  );

  if (existing.rowCount && existing.rowCount > 0) {
    res.status(409).json({ error: 'This calendar sync link is already linked' });
    return;
  }

  const color = await defaultColorForFamily(familyId);
  const displayName = trimmedNickname || 'Work shifts';

  const inserted = await pool.query(
    `INSERT INTO calendar_connections
      (family_id, source_type, feed_url, nickname, color)
     VALUES ($1, 'ics', $2, $3, $4)
     RETURNING ${CALENDAR_COLUMNS}`,
    [familyId, normalizedUrl, displayName, color],
  );

  const connectionId = inserted.rows[0].id as string;
  console.log(`ICS link saved (${displayName}): ${normalizedUrl}`);
  res.status(201).json(inserted.rows[0]);
  scheduleIcsSync(connectionId);
});

calendarsRouter.patch('/:id', requireFamilyAuth, async (req, res) => {
  const { nickname, color } = req.body as { nickname?: string; color?: string };

  if (nickname !== undefined && nickname.trim() === '') {
    res.status(400).json({ error: 'Nickname cannot be empty' });
    return;
  }
  if (color !== undefined && !CALENDAR_COLORS.includes(color)) {
    res.status(400).json({ error: 'Invalid color' });
    return;
  }

  const result = await pool.query(
    `UPDATE calendar_connections
     SET nickname = COALESCE($3, nickname),
         color = COALESCE($4, color)
     WHERE id = $1 AND family_id = $2
     RETURNING ${CALENDAR_COLUMNS}`,
    [req.params.id, req.auth!.familyId, nickname?.trim() ?? null, color ?? null],
  );
  if (result.rowCount === 0) {
    res.status(404).json({ error: 'Calendar not found' });
    return;
  }
  res.json(result.rows[0]);
});

calendarsRouter.get('/oauth/start', requireFamilyAuth, (req, res) => {
  if (!googleOAuthConfigured()) {
    res.status(503).json({ error: 'Google OAuth not configured on server' });
    return;
  }

  const client = oauthClient();
  const url = client.generateAuthUrl({
    access_type: 'offline',
    prompt: 'consent',
    scope: SCOPES,
    state: req.auth!.familyId,
  });
  res.json({ url });
});

calendarsRouter.get('/oauth/callback', async (req, res) => {
  if (!googleOAuthConfigured()) {
    res.status(503).send('Google OAuth not configured');
    return;
  }

  const code = req.query.code as string | undefined;
  const familyId = req.query.state as string | undefined;
  if (!code || !familyId) {
    res.status(400).send('Missing code or state');
    return;
  }

  try {
    const client = oauthClient();
    const { tokens } = await client.getToken(code);
    if (!tokens.refresh_token) {
      res.status(400).send('No refresh token received; try again with consent');
      return;
    }

    client.setCredentials(tokens);
    const oauth2 = google.oauth2({ version: 'v2', auth: client });
    const profile = await oauth2.userinfo.get();
    const email = profile.data.email;
    if (!email) {
      res.status(400).send('Could not read Google account email');
      return;
    }

    const calendar = google.calendar({ version: 'v3', auth: client });
    await calendar.events.list({
      calendarId: 'primary',
      maxResults: 1,
      singleEvents: true,
    });

    const encrypted = encrypt(tokens.refresh_token);
    const nickname = email.split('@')[0];
    const color = await defaultColorForFamily(familyId);

    const existing = await pool.query<{ id: string }>(
      `SELECT id FROM calendar_connections
       WHERE family_id = $1 AND source_type = 'google' AND google_account_email = $2`,
      [familyId, email],
    );

    let connectionId: string;
    if (existing.rowCount && existing.rowCount > 0) {
      connectionId = existing.rows[0].id;
      await pool.query(
        `UPDATE calendar_connections
         SET refresh_token_encrypted = $2
         WHERE id = $1`,
        [connectionId, encrypted],
      );
    } else {
      const inserted = await pool.query<{ id: string }>(
        `INSERT INTO calendar_connections
          (family_id, source_type, google_account_email, refresh_token_encrypted, nickname, color)
         VALUES ($1, 'google', $2, $3, $4, $5)
         RETURNING id`,
        [familyId, email, encrypted, nickname, color],
      );
      connectionId = inserted.rows[0].id;
    }

    void syncCalendarConnection(connectionId).catch((error) => {
      console.error(`Initial sync failed for ${email}:`, error);
    });

    res.send(
      '<html><body><h2>Calendar linked</h2><p>You can close this window and return to the app.</p></body></html>',
    );
  } catch (error) {
    console.error('OAuth callback failed:', error);
    const message =
      error instanceof Error && error.message.includes('Insufficient Permission')
        ? 'Calendar read permission was not granted. Remove Family Calendar at myaccount.google.com/permissions, then link again and allow calendar access.'
        : 'Failed to link calendar. Check server logs and try again.';
    res.status(500).send(message);
  }
});

export async function syncCalendarConnection(connectionId: string): Promise<void> {
  const result = await pool.query<{ source_type: string }>(
    'SELECT source_type FROM calendar_connections WHERE id = $1',
    [connectionId],
  );
  if (result.rowCount === 0) return;

  if (result.rows[0].source_type === 'ics') {
    await listIcsEventsForConnection(connectionId);
    return;
  }

  await listGoogleEventsForConnection(connectionId);
}

export async function listGoogleEventsForConnection(connectionId: string): Promise<void> {
  const result = await pool.query<{
    id: string;
    refresh_token_encrypted: string;
  }>(
    `SELECT id, refresh_token_encrypted
     FROM calendar_connections
     WHERE id = $1 AND source_type = 'google'`,
    [connectionId],
  );
  if (result.rowCount === 0) return;

  const row = result.rows[0];
  const client = oauthClient();
  client.setCredentials({ refresh_token: decrypt(row.refresh_token_encrypted) });

  const calendar = google.calendar({ version: 'v3', auth: client });
  const timeMin = new Date();
  timeMin.setDate(timeMin.getDate() - 30);
  const timeMax = new Date();
  timeMax.setDate(timeMax.getDate() + 120);

  const response = await calendar.events.list({
    calendarId: 'primary',
    timeMin: timeMin.toISOString(),
    timeMax: timeMax.toISOString(),
    singleEvents: true,
    orderBy: 'startTime',
    maxResults: 500,
    timeZone: config.familyTimeZone,
  }).catch((error: unknown) => {
    if (isRevokedGoogleTokenError(error)) {
      return null;
    }
    throw error;
  });

  if (!response) {
    console.error(
      `Google token revoked for connection ${connectionId} — re-link in mobile app`,
    );
    return;
  }

  const items = response.data.items ?? [];
  for (const item of items) {
    if (!item.id || !item.start || !item.end) continue;

    let startAt: Date;
    let endAt: Date;
    let allDay: boolean;
    try {
      ({ startAt, endAt, allDay } = parseGoogleEventRange(
        item.start,
        item.end,
        config.familyTimeZone,
      ));
    } catch {
      continue;
    }

    await pool.query(
      `INSERT INTO events
        (calendar_connection_id, google_event_id, title, description, location, start_at, end_at, all_day, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now())
       ON CONFLICT (calendar_connection_id, google_event_id)
       DO UPDATE SET
         title = EXCLUDED.title,
         description = EXCLUDED.description,
         location = EXCLUDED.location,
         start_at = EXCLUDED.start_at,
         end_at = EXCLUDED.end_at,
         all_day = EXCLUDED.all_day,
         updated_at = now()`,
      [
        row.id,
        item.id,
        item.summary ?? '(no title)',
        item.description ?? null,
        item.location ?? null,
        startAt,
        endAt,
        allDay,
      ],
    );
  }

  await pool.query(
    'UPDATE calendar_connections SET last_synced_at = now() WHERE id = $1',
    [row.id],
  );
}
