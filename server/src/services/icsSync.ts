import { pool } from '../db/pool.js';
import {
  fetchIcsText,
  normalizeFeedUrl,
  parseIcsEvents,
  validateFeedUrl,
} from './ics.js';

export async function listIcsEventsForConnection(connectionId: string): Promise<void> {
  const result = await pool.query<{
    id: string;
    feed_url: string;
  }>(
    `SELECT id, feed_url
     FROM calendar_connections
     WHERE id = $1 AND source_type = 'ics'`,
    [connectionId],
  );
  if (result.rowCount === 0) return;

  const row = result.rows[0];
  const icsText = await fetchIcsText(row.feed_url);
  const timeMin = new Date();
  timeMin.setDate(timeMin.getDate() - 30);
  const timeMax = new Date();
  timeMax.setDate(timeMax.getDate() + 120);

  const items = parseIcsEvents(icsText, timeMin, timeMax);
  const seenUids = new Set<string>();

  for (const item of items) {
    seenUids.add(item.uid);
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
        item.uid,
        item.title,
        item.description,
        item.location,
        item.startAt,
        item.endAt,
        item.allDay,
      ],
    );
  }

  if (seenUids.size > 0) {
    await pool.query(
      `DELETE FROM events
       WHERE calendar_connection_id = $1
         AND start_at >= $2
         AND start_at < $3
         AND NOT (google_event_id = ANY($4::text[]))`,
      [row.id, timeMin, timeMax, [...seenUids]],
    );
  }

  await pool.query(
    'UPDATE calendar_connections SET last_synced_at = now() WHERE id = $1',
    [row.id],
  );
}

export async function validateIcsFeedUrl(raw: string): Promise<string> {
  validateFeedUrl(raw);
  const normalized = normalizeFeedUrl(raw);
  await fetchIcsText(normalized);
  return normalized;
}
