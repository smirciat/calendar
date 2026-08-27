import { readFileSync, statSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export type TitleRuleSet = {
  title_keywords?: string[];
  title_contains?: string[];
  title_starts_with?: string[];
};

export type WorkShiftRuleSet = TitleRuleSet & {
  ics_calendars?: boolean;
};

export type EventDisplayRules = {
  doctor: TitleRuleSet;
  work_shift: WorkShiftRuleSet;
};

export type EventForDisplayPriority = {
  title: string;
  source_type?: string | null;
};

const serverRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const defaultRulesPath = resolve(serverRoot, 'event-display-rules.json');

let cachedRules: EventDisplayRules | null = null;
let cachedMtime = 0;

const defaultRules: EventDisplayRules = {
  doctor: {
    title_keywords: [],
    title_contains: ['doctor', ' appointment', 'appt'],
    title_starts_with: ['dr ', 'dr.', 'appointment'],
  },
  work_shift: {
    ics_calendars: true,
    title_keywords: [],
    title_contains: ['shift', 'work', 'on call', 'on-call'],
    title_starts_with: [],
  },
};

export function normalizeEventTitle(title: string): string {
  return title.trim().toLowerCase().replace(/\s+/g, ' ');
}

function matchesTitleRules(title: string, rules: TitleRuleSet): boolean {
  for (const keyword of rules.title_keywords ?? []) {
    if (keyword && title.includes(keyword.toLowerCase())) return true;
  }
  for (const fragment of rules.title_contains ?? []) {
    if (fragment && title.includes(fragment.toLowerCase())) return true;
  }
  for (const prefix of rules.title_starts_with ?? []) {
    if (prefix && title.startsWith(prefix.toLowerCase())) return true;
  }
  return false;
}

export function eventDisplayPriority(
  event: EventForDisplayPriority,
  rules: EventDisplayRules = getEventDisplayRules(),
): number {
  const title = normalizeEventTitle(event.title);

  if (matchesTitleRules(title, rules.doctor)) {
    return 0;
  }

  if (
    (rules.work_shift.ics_calendars && event.source_type === 'ics') ||
    matchesTitleRules(title, rules.work_shift)
  ) {
    return 1;
  }

  return 2;
}

export function getEventDisplayRules(): EventDisplayRules {
  const path =
    process.env.EVENT_DISPLAY_RULES_PATH ??
    defaultRulesPath;

  try {
    const mtime = statSync(path).mtimeMs;
    if (cachedRules && mtime === cachedMtime) {
      return cachedRules;
    }

    const parsed = JSON.parse(readFileSync(path, 'utf8')) as Partial<EventDisplayRules>;
    cachedRules = {
      doctor: { ...defaultRules.doctor, ...parsed.doctor },
      work_shift: { ...defaultRules.work_shift, ...parsed.work_shift },
    };
    cachedMtime = mtime;
    return cachedRules;
  } catch (error) {
    console.warn(
      `Event display rules unavailable (${path}); using defaults.`,
      error,
    );
    return defaultRules;
  }
}
