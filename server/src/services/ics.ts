import ical, { type VEvent } from 'node-ical';

export function normalizeFeedUrl(raw: string): string {
  const trimmed = raw.trim();
  if (trimmed.startsWith('webcal://')) {
    return `https://${trimmed.slice('webcal://'.length)}`;
  }
  if (trimmed.startsWith('webcals://')) {
    return `https://${trimmed.slice('webcals://'.length)}`;
  }
  return trimmed;
}

export function validateFeedUrl(raw: string): URL {
  let parsed: URL;
  try {
    parsed = new URL(normalizeFeedUrl(raw));
  } catch {
    throw new Error('Invalid calendar sync link');
  }

  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new Error('Calendar sync link must use http or https');
  }

  return parsed;
}

export async function fetchIcsText(
  feedUrl: string,
  { timeoutMs = 30_000, maxBytes = 5 * 1024 * 1024 } = {},
): Promise<string> {
  const normalized = normalizeFeedUrl(feedUrl);
  validateFeedUrl(normalized);

  const response = await fetch(normalized, {
    headers: {
      Accept: 'text/calendar,text/plain,*/*',
      'User-Agent': 'FamilyCalendar/1.0',
    },
    signal: AbortSignal.timeout(timeoutMs),
  });

  if (!response.ok) {
    throw new Error(`Could not fetch calendar feed (${response.status})`);
  }

  const reader = response.body?.getReader();
  if (!reader) {
    const text = await response.text();
    if (!text.includes('BEGIN:VCALENDAR')) {
      throw new Error('Link does not look like a calendar feed');
    }
    return text;
  }

  const chunks: Uint8Array[] = [];
  let totalBytes = 0;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    totalBytes += value.byteLength;
    if (totalBytes > maxBytes) {
      throw new Error('Calendar feed is too large to sync');
    }
    chunks.push(value);
  }

  const text = Buffer.concat(chunks).toString('utf8');
  if (!text.includes('BEGIN:VCALENDAR')) {
    throw new Error('Link does not look like a calendar feed');
  }

  return text;
}

export type ParsedIcsEvent = {
  uid: string;
  title: string;
  description: string | null;
  location: string | null;
  startAt: Date;
  endAt: Date;
  allDay: boolean;
};

function isDateOnly(value: Date): boolean {
  return (
    value.getUTCHours() === 0 &&
    value.getUTCMinutes() === 0 &&
    value.getUTCSeconds() === 0 &&
    value.getUTCMilliseconds() === 0
  );
}

function eventUid(item: VEvent, fallback: string): string {
  if (typeof item.uid === 'string' && item.uid.trim() !== '') {
    return item.uid.trim();
  }
  return fallback;
}

export function parseIcsEvents(
  icsText: string,
  timeMin: Date,
  timeMax: Date,
): ParsedIcsEvent[] {
  const parsed = ical.sync.parseICS(icsText);
  const events: ParsedIcsEvent[] = [];

  for (const [key, item] of Object.entries(parsed)) {
    if (!item || item.type !== 'VEVENT') continue;
    const event = item as VEvent;
    if (!event.start || !event.end) continue;

    const startAt = event.start instanceof Date ? event.start : new Date(event.start);
    const endAt = event.end instanceof Date ? event.end : new Date(event.end);
    if (Number.isNaN(startAt.valueOf()) || Number.isNaN(endAt.valueOf())) continue;
    if (startAt >= timeMax || endAt <= timeMin) continue;

    const allDay =
      event.datetype === 'date' ||
      (isDateOnly(startAt) &&
        isDateOnly(endAt) &&
        endAt.getTime() - startAt.getTime() >= 86_400_000);

    events.push({
      uid: eventUid(event, key),
      title:
        typeof event.summary === 'string' && event.summary.trim() !== ''
          ? event.summary.trim()
          : '(no title)',
      description:
        typeof event.description === 'string' ? event.description : null,
      location: typeof event.location === 'string' ? event.location : null,
      startAt,
      endAt,
      allDay,
    });
  }

  return events;
}
