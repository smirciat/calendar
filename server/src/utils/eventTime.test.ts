import test from 'node:test';
import assert from 'node:assert/strict';
import { parseGoogleEventRange } from '../utils/eventTime.js';

test('parseGoogleEventRange uses event timeZone for naive dateTime', () => {
  const { startAt, allDay } = parseGoogleEventRange(
    {
      dateTime: '2026-08-27T15:30:00',
      timeZone: 'America/Los_Angeles',
    },
    {
      dateTime: '2026-08-27T16:30:00',
      timeZone: 'America/Los_Angeles',
    },
    'America/Los_Angeles',
  );

  assert.equal(allDay, false);
  assert.equal(startAt.toISOString(), '2026-08-27T22:30:00.000Z');
});

test('parseGoogleEventRange accepts RFC3339 offset', () => {
  const { startAt } = parseGoogleEventRange(
    { dateTime: '2026-08-27T15:30:00-07:00' },
    { dateTime: '2026-08-27T16:30:00-07:00' },
    'America/Los_Angeles',
  );

  assert.equal(startAt.toISOString(), '2026-08-27T22:30:00.000Z');
});
