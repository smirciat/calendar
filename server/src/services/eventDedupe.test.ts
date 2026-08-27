import test from 'node:test';
import assert from 'node:assert/strict';
import {
  dedupeFamilyEvents,
  eventsHaveSimilarTimes,
  sharedDedupeKeyword,
  shouldMergeEvents,
} from './eventDedupe.js';

const rules = {
  title_keywords: ['bobby', 'abby'],
  start_tolerance_minutes: 15,
};

function event(overrides: Partial<{
  id: string;
  title: string;
  calendar_connection_id: string;
  start_at: string;
  end_at: string;
  all_day: boolean;
  source_type: string;
}> = {}) {
  return {
    id: overrides.id ?? '1',
    title: overrides.title ?? 'Bobby counseling',
    calendar_connection_id: overrides.calendar_connection_id ?? 'aj',
    start_at: overrides.start_at ?? '2026-09-03T20:00:00.000Z',
    end_at: overrides.end_at ?? '2026-09-03T21:00:00.000Z',
    all_day: overrides.all_day ?? false,
    source_type: overrides.source_type ?? 'google',
  };
}

test('sharedDedupeKeyword matches case-insensitive substring', () => {
  assert.equal(
    sharedDedupeKeyword('Bobby counseling', 'AJ/Bobby', ['bobby', 'abby']),
    'bobby',
  );
  assert.equal(
    sharedDedupeKeyword('Abby doctor', 'Appointment for Abby', ['bobby', 'abby']),
    'abby',
  );
  assert.equal(
    sharedDedupeKeyword('Bobby counseling', 'Tracy shift', ['bobby', 'abby']),
    null,
  );
});

test('eventsHaveSimilarTimes accepts exact and nearby timed events', () => {
  const a = event();
  const b = event({
    start_at: '2026-09-03T20:10:00.000Z',
    end_at: '2026-09-03T21:10:00.000Z',
  });
  assert.equal(eventsHaveSimilarTimes(a, b, 15, 'America/Los_Angeles'), true);
  assert.equal(eventsHaveSimilarTimes(a, b, 5, 'America/Los_Angeles'), false);
});

test('shouldMergeEvents merges cross-calendar Bobby events at same time', () => {
  const aj = event({ id: 'aj', title: 'Bobby counseling', calendar_connection_id: 'aj' });
  const tracy = event({
    id: 'tracy',
    title: 'AJ/Bobby',
    calendar_connection_id: 'tracy',
  });
  assert.equal(shouldMergeEvents(aj, tracy, rules), true);
});

test('shouldMergeEvents does not merge same calendar or unrelated titles', () => {
  const a = event({ calendar_connection_id: 'aj' });
  const b = event({ id: '2', calendar_connection_id: 'aj', title: 'AJ/Bobby' });
  const c = event({
    id: '3',
    calendar_connection_id: 'tracy',
    title: 'Soccer practice',
  });
  assert.equal(shouldMergeEvents(a, b, rules), false);
  assert.equal(shouldMergeEvents(a, c, rules), false);
});

test('dedupeFamilyEvents keeps one primary event per matching group', () => {
  const merged = dedupeFamilyEvents(
    [
      event({ id: 'aj', title: 'Bobby counseling', calendar_connection_id: 'aj' }),
      event({ id: 'tracy', title: 'AJ/Bobby', calendar_connection_id: 'tracy' }),
      event({
        id: 'other',
        title: 'Dinner',
        calendar_connection_id: 'andy',
        start_at: '2026-09-04T01:00:00.000Z',
        end_at: '2026-09-04T02:00:00.000Z',
      }),
    ],
    rules,
  );

  assert.equal(merged.length, 2);
  assert.equal(
    merged.some((item) => item.title.toLowerCase().includes('bobby')),
    true,
  );
  assert.equal(merged.some((item) => item.title === 'Dinner'), true);
});
