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

  const batchSize = 100;
  for (let offset = 0; offset < items.length; offset += batchSize) {
    const batch = items.slice(offset, offset + batchSize);
    for (const item of batch) {
      seenUids.add(item.uid);
    }

    const connectionIds: string[] = [];
    const eventIds: string[] = [];
    const titles: string[] = [];
    const descriptions: (string | null)[] = [];
    const locations: (string | null)[] = [];
    const starts: Date[] = [];
    const ends: Date[] = [];
    const allDays: boolean[] = [];

    for (const item of batch) {
      connectionIds.push(row.id);
      eventIds.push(item.uid);
      titles.push(item.title);
      descriptions.push(item.description);
      locations.push(item.location);
      starts.push(item.startAt);
      ends.push(item.endAt);
      allDays.push(item.allDay);
    }

    await pool.query(
      `INSERT INTO events
        (calendar_connection_id, google_event_id, title, description, location, start_at, end_at, all_day, updated_at)
       SELECT
         calendar_connection_id,
         google_event_id,
         title,
         description,
         location,
         start_at,
         end_at,
         all_day,
         now()
       FROM UNNEST(
         $1::uuid[],
         $2::text[],
         $3::text[],
         $4::text[],
         $5::text[],
         $6::timestamptz[],
         $7::timestamptz[],
         $8::boolean[]
       ) AS t(
         calendar_connection_id,
         google_event_id,
         title,
         description,
         location,
         start_at,
         end_at,
         all_day
       )
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
        connectionIds,
        eventIds,
        titles,
        descriptions,
        locations,
        starts,
        ends,
        allDays,
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

export function validateIcsFeedUrl(raw: string): string {
  validateFeedUrl(raw);
  return normalizeFeedUrl(raw);
}
