import 'package:family_calendar/models/calendar_models.dart';

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
  return events
      .where((event) => eventOccursOnDay(event, day))
      .toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
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

String _dedupeKey(CalendarEvent event) {
  final title = event.title.trim().toLowerCase();
  if (event.allDay) {
    return '$title|${event.startAt.year}-${event.startAt.month}-${event.startAt.day}|allDay';
  }
  final startMinute = event.startAt.millisecondsSinceEpoch ~/ 60000;
  final endMinute = event.endAt.millisecondsSinceEpoch ~/ 60000;
  return '$title|$startMinute|$endMinute';
}

List<EventDisplayGroup> groupDuplicateEvents(List<CalendarEvent> events) {
  final sorted = [...events]..sort((a, b) => a.startAt.compareTo(b.startAt));
  final groups = <EventDisplayGroup>[];
  final keyToIndex = <String, int>{};

  for (final event in sorted) {
    final key = _dedupeKey(event);
    final existingIndex = keyToIndex[key];
    if (existingIndex == null) {
      keyToIndex[key] = groups.length;
      groups.add(EventDisplayGroup([event]));
    } else {
      groups[existingIndex].events.add(event);
    }
  }

  return groups;
}
