import { DateTime } from 'luxon';

type GoogleEventDateTime = {
  date?: string | null;
  dateTime?: string | null;
  timeZone?: string | null;
};

const RFC3339_OFFSET = /[zZ]$|[+-]\d{2}:\d{2}$/;

/** Parse Google Calendar EventDateTime to a UTC instant. */
export function parseGoogleEventDateTime(
  value: GoogleEventDateTime,
  defaultTimeZone: string,
): Date {
  if (value.date) {
    return new Date(`${value.date}T00:00:00Z`);
  }

  const raw = value.dateTime;
  if (!raw) {
    throw new Error('Google event is missing start/end dateTime');
  }

  if (RFC3339_OFFSET.test(raw)) {
    return new Date(raw);
  }

  const zone = value.timeZone ?? defaultTimeZone;
  const parsed = DateTime.fromISO(raw, { zone });
  if (!parsed.isValid) {
    throw new Error(`Invalid Google dateTime: ${raw} (${parsed.invalidReason})`);
  }

  return parsed.toUTC().toJSDate();
}

export function parseGoogleEventRange(
  start: GoogleEventDateTime | undefined | null,
  end: GoogleEventDateTime | undefined | null,
  defaultTimeZone: string,
): { startAt: Date; endAt: Date; allDay: boolean } {
  if (!start || !end) {
    throw new Error('Google event is missing start or end');
  }

  const allDay = Boolean(start.date);
  if (allDay) {
    return {
      startAt: new Date(`${start.date}T00:00:00Z`),
      endAt: new Date(`${end.date}T00:00:00Z`),
      allDay: true,
    };
  }

  return {
    startAt: parseGoogleEventDateTime(start, defaultTimeZone),
    endAt: parseGoogleEventDateTime(end, defaultTimeZone),
    allDay: false,
  };
}
