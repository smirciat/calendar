import { DateTime } from 'luxon';
import { config } from '../config.js';
import {
  eventDisplayPriority,
  normalizeEventTitle,
  type EventForDisplayPriority,
} from './eventDisplayRules.js';

export type DedupeRuleSet = {
  title_keywords?: string[];
  start_tolerance_minutes?: number;
};

export type EventForDedupe = EventForDisplayPriority & {
  id: string;
  title: string;
  start_at: Date | string;
  end_at: Date | string;
  all_day: boolean;
  calendar_connection_id: string;
  nickname?: string;
  color?: string;
};

function asDate(value: Date | string): Date {
  return value instanceof Date ? value : new Date(value);
}

function eventDayKey(event: EventForDedupe, timeZone: string): string {
  const start = DateTime.fromJSDate(asDate(event.start_at), { zone: 'utc' }).setZone(
    timeZone,
  );
  return start.toISODate() ?? '';
}

function minutesApart(a: Date | string, b: Date | string): number {
  return Math.abs(asDate(a).getTime() - asDate(b).getTime()) / 60_000;
}

export function sharedDedupeKeyword(
  titleA: string,
  titleB: string,
  keywords: string[],
): string | null {
  const normalizedA = normalizeEventTitle(titleA);
  const normalizedB = normalizeEventTitle(titleB);
  for (const keyword of keywords) {
    const needle = keyword.trim().toLowerCase();
    if (!needle) continue;
    if (normalizedA.includes(needle) && normalizedB.includes(needle)) {
      return needle;
    }
  }
  return null;
}

export function eventsHaveSimilarTimes(
  a: EventForDedupe,
  b: EventForDedupe,
  toleranceMinutes: number,
  timeZone: string,
): boolean {
  if (a.all_day !== b.all_day) return false;

  if (a.all_day) {
    return eventDayKey(a, timeZone) === eventDayKey(b, timeZone);
  }

  return (
    minutesApart(a.start_at, b.start_at) <= toleranceMinutes &&
    minutesApart(a.end_at, b.end_at) <= toleranceMinutes
  );
}

export function shouldMergeEvents(
  a: EventForDedupe,
  b: EventForDedupe,
  rules: DedupeRuleSet,
  timeZone: string = config.familyTimeZone,
): boolean {
  if (a.id === b.id) return false;
  if (a.calendar_connection_id === b.calendar_connection_id) return false;

  const keywords = rules.title_keywords ?? [];
  if (keywords.length === 0) return false;

  if (!sharedDedupeKeyword(a.title, b.title, keywords)) return false;

  const tolerance = rules.start_tolerance_minutes ?? 15;
  return eventsHaveSimilarTimes(a, b, tolerance, timeZone);
}

function comparePrimaryEvents(a: EventForDedupe, b: EventForDedupe): number {
  const byPriority = eventDisplayPriority(a) - eventDisplayPriority(b);
  if (byPriority !== 0) return byPriority;

  const byStart = asDate(a.start_at).getTime() - asDate(b.start_at).getTime();
  if (byStart !== 0) return byStart;

  return b.title.length - a.title.length;
}

export function dedupeFamilyEvents<T extends EventForDedupe>(
  events: T[],
  rules: DedupeRuleSet,
  timeZone: string = config.familyTimeZone,
): T[] {
  const keywords = rules.title_keywords ?? [];
  if (keywords.length === 0 || events.length < 2) {
    return events;
  }

  const sorted = [...events].sort(comparePrimaryEvents);
  const groups: T[][] = [];

  for (const event of sorted) {
    let placed = false;
    for (const group of groups) {
      if (group.some((member) => shouldMergeEvents(member, event, rules, timeZone))) {
        group.push(event);
        placed = true;
        break;
      }
    }
    if (!placed) {
      groups.push([event]);
    }
  }

  return groups.map((group) => {
    const primary = [...group].sort(comparePrimaryEvents)[0];
    return primary;
  });
}
