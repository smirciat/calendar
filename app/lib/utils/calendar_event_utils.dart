import 'package:family_calendar/models/calendar_models.dart';

/// Match server default sync interval (see SYNC_INTERVAL_MS in .env).
const calendarEventPollInterval = Duration(seconds: 60);

const calendarFontScaleOptions = <double>[0.85, 1.0, 1.15, 1.3, 1.5];

class EventDisplayGroup {
  EventDisplayGroup(this.events) : assert(events.isNotEmpty);

  final List<CalendarEvent> events;

  CalendarEvent get primary => events.first;

  int get duplicateCount => events.length - 1;

  bool get hasDuplicates => events.length > 1;
}

class WeekSpanSegment {
  WeekSpanSegment({
    required this.group,
    required this.startColumn,
    required this.endColumn,
    required this.continuesBefore,
    required this.continuesAfter,
    required this.showTitle,
    required this.lane,
  });

  final EventDisplayGroup group;
  final int startColumn;
  final int endColumn;
  final bool continuesBefore;
  final bool continuesAfter;
  final bool showTitle;
  final int lane;
}

String normalizeEventTitle(String title) {
  return title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Lower number = shown higher in the day list.
int eventDisplayPriority(CalendarEvent event) {
  final title = normalizeEventTitle(event.title);
  if (title.contains('doctor') ||
      title.startsWith('dr ') ||
      title.startsWith('dr.') ||
      title.contains(' appointment') ||
      title.startsWith('appointment') ||
      title.contains('appt')) {
    return 0;
  }
  if (title.contains('shift') ||
      title.contains('work') ||
      title.contains('on call') ||
      title.contains('on-call')) {
    return 1;
  }
  return 2;
}

int compareEventsForDisplay(CalendarEvent a, CalendarEvent b) {
  final byPriority = eventDisplayPriority(a).compareTo(eventDisplayPriority(b));
  if (byPriority != 0) return byPriority;
  final byStart = a.startAt.compareTo(b.startAt);
  if (byStart != 0) return byStart;
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

int compareEventGroupsForDisplay(EventDisplayGroup a, EventDisplayGroup b) {
  return compareEventsForDisplay(a.primary, b.primary);
}

DateTime eventStartDay(CalendarEvent event) {
  if (event.allDay) {
    return DateTime(
      event.startAt.year,
      event.startAt.month,
      event.startAt.day,
    );
  }
  final local = event.startAt.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime eventEndDay(CalendarEvent event) {
  if (event.allDay) {
    return DateTime(
      event.endAt.year,
      event.endAt.month,
      event.endAt.day,
    );
  }
  final local = event.endAt.toLocal();
  return DateTime(local.year, local.month, local.day);
}

bool eventSpansMultipleDays(CalendarEvent event) {
  return eventEndDay(event).isAfter(eventStartDay(event));
}

bool eventOccursOnDay(CalendarEvent event, DateTime day) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  if (event.allDay) {
    final eventStartDay = DateTime(
      event.startAt.year,
      event.startAt.month,
      event.startAt.day,
    );
    final eventEndDay = DateTime(
      event.endAt.year,
      event.endAt.month,
      event.endAt.day,
    );
    return !eventStartDay.isAfter(dayStart) && eventEndDay.isAfter(dayStart);
  }

  return event.startAt.isBefore(dayEnd) && event.endAt.isAfter(dayStart);
}

List<CalendarEvent> eventsForDay(List<CalendarEvent> events, DateTime day) {
  final dayEvents = events
      .where((event) => eventOccursOnDay(event, day))
      .toList();
  dayEvents.sort(compareEventsForDisplay);
  return dayEvents;
}

List<CalendarEvent> singleDayEventsForDay(
  List<CalendarEvent> events,
  DateTime day,
) {
  return eventsForDay(events, day)
      .where((event) => !eventSpansMultipleDays(event))
      .toList();
}

List<EventDisplayGroup> multiDayGroupsForWeek(
  List<DateTime> week,
  List<CalendarEvent> events,
) {
  final spanning = events.where((event) {
    if (!eventSpansMultipleDays(event)) return false;
    return week.any((day) => eventOccursOnDay(event, day));
  }).toList();
  return groupDuplicateEvents(spanning);
}

List<WeekSpanSegment> layoutWeekSpans(List<DateTime> week, List<EventDisplayGroup> groups) {
  final segments = <WeekSpanSegment>[];

  for (final group in groups) {
    final event = group.primary;
    var startColumn = -1;
    var endColumn = -1;

    for (var i = 0; i < week.length; i++) {
      if (eventOccursOnDay(event, week[i])) {
        startColumn = startColumn == -1 ? i : startColumn;
        endColumn = i;
      }
    }

    if (startColumn == -1) continue;

    final continuesBefore = eventOccursOnDay(
      event,
      week.first.subtract(const Duration(days: 1)),
    );
    final continuesAfter = eventOccursOnDay(
      event,
      week.last.add(const Duration(days: 1)),
    );
    final eventStart = eventStartDay(event);
    final showTitle =
        !eventStart.isBefore(week[startColumn]) &&
        !eventStart.isAfter(week[endColumn]);

    segments.add(
      WeekSpanSegment(
        group: group,
        startColumn: startColumn,
        endColumn: endColumn,
        continuesBefore: continuesBefore,
        continuesAfter: continuesAfter,
        showTitle: showTitle,
        lane: 0,
      ),
    );
  }

  segments.sort((a, b) {
    final byStart = a.startColumn.compareTo(b.startColumn);
    if (byStart != 0) return byStart;
    final aLen = a.endColumn - a.startColumn;
    final bLen = b.endColumn - b.startColumn;
    return bLen.compareTo(aLen);
  });

  final laneEnds = <int>[];
  final placed = <WeekSpanSegment>[];
  for (final segment in segments) {
    var lane = 0;
    while (lane < laneEnds.length && segment.startColumn <= laneEnds[lane]) {
      lane++;
    }
    if (lane >= laneEnds.length) {
      laneEnds.add(segment.endColumn);
    } else {
      laneEnds[lane] = segment.endColumn;
    }

    placed.add(
      WeekSpanSegment(
        group: segment.group,
        startColumn: segment.startColumn,
        endColumn: segment.endColumn,
        continuesBefore: segment.continuesBefore,
        continuesAfter: segment.continuesAfter,
        showTitle: segment.showTitle,
        lane: lane,
      ),
    );
  }

  return placed;
}

String _dayKey(DateTime day) => '${day.year}-${day.month}-${day.day}';

String _dedupeKey(CalendarEvent event, {DateTime? onDay}) {
  final title = normalizeEventTitle(event.title);
  final day = onDay != null
      ? DateTime(onDay.year, onDay.month, onDay.day)
      : eventStartDay(event);
  final dayKey = _dayKey(day);

  // Same calendar day view: match by title only so all-day spans, daily
  // all-day entries, and timed blocks for the same real-world event merge.
  if (onDay != null) {
    return '$title|$dayKey';
  }

  if (event.allDay) {
    return '$title|$dayKey|allDay';
  }

  final local = event.startAt.toLocal();
  return '$title|$dayKey|${local.hour}:${local.minute}';
}

List<EventDisplayGroup> groupDuplicateEvents(
  List<CalendarEvent> events, {
  DateTime? onDay,
}) {
  final sorted = [...events]..sort(compareEventsForDisplay);
  final groups = <EventDisplayGroup>[];
  final keyToIndex = <String, int>{};

  for (final event in sorted) {
    final key = _dedupeKey(event, onDay: onDay);
    final existingIndex = keyToIndex[key];
    if (existingIndex == null) {
      keyToIndex[key] = groups.length;
      groups.add(EventDisplayGroup([event]));
    } else {
      groups[existingIndex].events.add(event);
    }
  }

  groups.sort(compareEventGroupsForDisplay);
  return groups;
}

String fontScaleLabel(double scale) {
  if (scale <= 0.9) return 'Small';
  if (scale <= 1.05) return 'Default';
  if (scale <= 1.2) return 'Large';
  if (scale <= 1.35) return 'X-Large';
  return 'XX-Large';
}
