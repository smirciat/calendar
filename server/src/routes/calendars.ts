import { google } from 'googleapis';
import { Router } from 'express';
import { config, googleOAuthConfigured } from '../config.js';
import { pool } from '../db/pool.js';
import { requireFamilyAuth } from '../middleware/auth.js';
import { decrypt, encrypt } from '../services/crypto.js';

export const calendarsRouter = Router();

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
    `SELECT id, google_account_email, nickname, color, created_at, last_synced_at
     FROM calendar_connections
     WHERE family_id = $1
     ORDER BY created_at ASC`,
    [req.auth!.familyId],
  );
  res.json(result.rows);
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
     RETURNING id, google_account_email, nickname, color, created_at, last_synced_at`,
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

    const inserted = await pool.query<{ id: string }>(
      `INSERT INTO calendar_connections
        (family_id, google_account_email, refresh_token_encrypted, nickname, color)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (family_id, google_account_email)
       DO UPDATE SET refresh_token_encrypted = EXCLUDED.refresh_token_encrypted
       RETURNING id`,
      [familyId, email, encrypted, nickname, color],
    );

    void listGoogleEventsForConnection(inserted.rows[0].id).catch((error) => {
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

export async function listGoogleEventsForConnection(connectionId: string): Promise<void> {
  const result = await pool.query<{
    id: string;
    refresh_token_encrypted: string;
  }>(
    'SELECT id, refresh_token_encrypted FROM calendar_connections WHERE id = $1',
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
  });

  const items = response.data.items ?? [];
  for (const item of items) {
    if (!item.id || !item.start || !item.end) continue;

    const allDay = Boolean(item.start.date);
    const startAt = allDay
      ? new Date(`${item.start.date}T00:00:00Z`)
      : new Date(item.start.dateTime!);
    const endAt = allDay
      ? new Date(`${item.end.date}T00:00:00Z`)
      : new Date(item.end.dateTime!);

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
