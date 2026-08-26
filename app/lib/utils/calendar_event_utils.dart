import 'package:family_calendar/models/calendar_models.dart';

class EventDisplayGroup {
  EventDisplayGroup(this.events) : assert(events.isNotEmpty);

  final List<CalendarEvent> events;

  CalendarEvent get primary => events.first;

  int get duplicateCount => events.length - 1;

  bool get hasDuplicates => events.length > 1;
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
