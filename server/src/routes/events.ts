import { Router } from 'express';
import { pool } from '../db/pool.js';
import { requireFamilyOrDeviceAuth } from '../middleware/auth.js';
import { dedupeFamilyEvents } from '../services/eventDedupe.js';
import {
  eventDisplayPriority,
  getEventDisplayRules,
} from '../services/eventDisplayRules.js';

export const eventsRouter = Router();

eventsRouter.get('/', requireFamilyOrDeviceAuth, async (req, res) => {
  const from = req.query.from as string | undefined;
  const to = req.query.to as string | undefined;

  if (!from || !to) {
    res.status(400).json({ error: 'from and to query params required (ISO dates)' });
    return;
  }

  const familyId = req.auth!.familyId;
  const result = await pool.query(
    `SELECT
       e.id,
       e.title,
       e.description,
       e.location,
       e.start_at,
       e.end_at,
       e.all_day,
       e.calendar_connection_id,
       c.nickname,
       c.color,
       c.google_account_email,
       c.source_type
     FROM events e
     JOIN calendar_connections c ON c.id = e.calendar_connection_id
     WHERE c.family_id = $1
       AND e.start_at < $3::timestamptz
       AND e.end_at > $2::timestamptz
     ORDER BY e.start_at ASC`,
    [familyId, from, to],
  );

  const withPriority = result.rows.map((row) => ({
    ...row,
    display_priority: eventDisplayPriority(row),
  }));

  const deduped = dedupeFamilyEvents(
    withPriority,
    getEventDisplayRules().dedupe ?? {},
  );

  res.json(
    deduped.map(({ calendar_connection_id: _calendarConnectionId, ...row }) => row),
  );
});
