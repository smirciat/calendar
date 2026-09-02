import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_calendar/models/calendar_models.dart';
import 'package:family_calendar/utils/calendar_colors.dart';
import 'package:family_calendar/utils/calendar_event_utils.dart';
import 'package:family_calendar/widgets/calendar_grid.dart';

CalendarEvent _event({
  required String id,
  required String title,
  required DateTime startAt,
  required DateTime endAt,
  bool allDay = false,
  String nickname = 'Dad',
  String color = '#4285F4',
  String sourceType = 'google',
  int? displayPriority,
}) {
  return CalendarEvent(
    id: id,
    title: title,
    startAt: startAt,
    endAt: endAt,
    allDay: allDay,
    nickname: nickname,
    color: color,
    sourceType: sourceType,
    displayPriority: displayPriority,
  );
}

void main() {
  test('buildWeekGrid returns requested week rows', () {
    final weeks = buildWeekGrid(anchor: DateTime(2026, 8, 26), weekCount: 5);
    expect(weeks.length, 5);
    expect(weeks.first.length, 7);
    expect(weeks.first.first.weekday, DateTime.sunday);
  });

  test('all-day events match by calendar date not local timezone', () {
    final event = _event(
      id: '1',
      title: 'Birthday',
      startAt: DateTime.utc(2026, 8, 26),
      endAt: DateTime.utc(2026, 8, 27),
      allDay: true,
    );

    expect(
      eventOccursOnDay(event, DateTime(2026, 8, 26)),
      isTrue,
    );
    expect(
      eventOccursOnDay(event, DateTime(2026, 8, 25)),
      isFalse,
    );
  });

  test('groupDuplicateEvents collapses same title and time', () {
    final start = DateTime(2026, 8, 26, 18, 0);
    final end = DateTime(2026, 8, 26, 19, 0);
    final events = [
      _event(id: '1', title: 'Dinner', startAt: start, endAt: end, nickname: 'Dad'),
      _event(id: '2', title: 'Dinner', startAt: start, endAt: end, nickname: 'Mom'),
      _event(id: '3', title: 'Soccer', startAt: start, endAt: end, nickname: 'Kid'),
    ];

    final groups = groupDuplicateEvents(events);

    expect(groups.length, 2);
    expect(groups.first.events.length, 2);
    expect(groups.first.duplicateCount, 1);
    expect(groups.last.events.length, 1);
  });

  test('groupDuplicateEvents matches multi-day and daily all-day on same day', () {
    final day = DateTime(2026, 8, 27);
    final multiDay = _event(
      id: '1',
      title: 'Oregon State Fair',
      startAt: DateTime.utc(2026, 8, 22),
      endAt: DateTime.utc(2026, 8, 31),
      allDay: true,
      nickname: 'Allie',
    );
    final singleDay = _event(
      id: '2',
      title: 'Oregon State Fair',
      startAt: DateTime.utc(2026, 8, 27),
      endAt: DateTime.utc(2026, 8, 28),
      allDay: true,
      nickname: 'Tracy',
    );

    final dayEvents = eventsForDay([multiDay, singleDay], day);
    final groups = groupDuplicateEvents(dayEvents, onDay: day);

    expect(groups.length, 1);
    expect(groups.first.events.length, 2);
    expect(groups.first.duplicateCount, 1);
  });

  test('groupDuplicateEvents keeps all-day and timed same-title separate on day grid', () {
    final day = DateTime(2026, 8, 27);
    final multiDay = _event(
      id: '1',
      title: 'Oregon State Fair',
      startAt: DateTime.utc(2026, 8, 22),
      endAt: DateTime.utc(2026, 8, 31),
      allDay: true,
      nickname: 'Allie',
    );
    final timedDaily = _event(
      id: '2',
      title: 'Oregon State Fair',
      startAt: DateTime(2026, 8, 27, 10, 0),
      endAt: DateTime(2026, 8, 27, 22, 0),
      nickname: 'Tracy',
    );

    final dayEvents = eventsForDay([multiDay, timedDaily], day);
    final groups = groupDuplicateEvents(dayEvents, onDay: day);

    expect(groups.length, 2);
    expect(groups.every((group) => group.events.length == 1), isTrue);
  });

  test('groupDuplicateEvents matches titles case-insensitively', () {
    final start = DateTime(2026, 8, 26, 18, 0);
    final end = DateTime(2026, 8, 26, 19, 0);
    final events = [
      _event(id: '1', title: 'Dinner', startAt: start, endAt: end, nickname: 'Dad'),
      _event(id: '2', title: 'DINNER', startAt: start, endAt: end, nickname: 'Mom'),
    ];

    final groups = groupDuplicateEvents(events);

    expect(groups.length, 1);
    expect(groups.first.events.length, 2);
  });

  test('groupDuplicateEvents keeps same-title shifts separate on day grid', () {
    final day = DateTime(2026, 9, 12);
    final events = [
      _event(
        id: '1',
        title: 'Crew Counter at BV11 - Albany',
        startAt: DateTime(2026, 9, 12, 12, 0),
        endAt: DateTime(2026, 9, 12, 17, 0),
        nickname: 'Allie',
      ),
      _event(
        id: '2',
        title: 'Crew Counter at BV11 - Albany',
        startAt: DateTime(2026, 9, 12, 19, 0),
        endAt: DateTime(2026, 9, 12, 23, 30),
        nickname: 'AJ',
      ),
    ];

    final groups = groupDuplicateEvents(events, onDay: day);

    expect(groups.length, 2);
    expect(groups.every((group) => group.events.length == 1), isTrue);
  });

  test('eventsForDay puts ICS work shift calendars near the top', () {
    final day = DateTime(2026, 8, 26);
    final start = DateTime(2026, 8, 26, 9, 0);
    final end = DateTime(2026, 8, 26, 17, 0);
    final events = [
      _event(id: '1', title: 'Groceries', startAt: start, endAt: end),
      _event(
        id: '2',
        title: '7:00 AM - 3:00 PM',
        startAt: start,
        endAt: end,
        sourceType: 'ics',
        nickname: 'Cody',
        displayPriority: 1,
      ),
      _event(id: '3', title: 'Soccer', startAt: start, endAt: end),
    ];

    final sorted = eventsForDay(events, day);

    expect(sorted.first.title, '7:00 AM - 3:00 PM');
  });

  test('eventsForDay puts doctor appointments and shifts first', () {
    final day = DateTime(2026, 8, 26);
    final start = DateTime(2026, 8, 26, 9, 0);
    final end = DateTime(2026, 8, 26, 10, 0);
    final events = [
      _event(id: '1', title: 'Soccer', startAt: start, endAt: end, displayPriority: 2),
      _event(id: '2', title: 'Doctor visit', startAt: start, endAt: end, displayPriority: 0),
      _event(id: '3', title: 'Night shift', startAt: start, endAt: end, displayPriority: 1),
      _event(id: '4', title: 'Lunch', startAt: start, endAt: end, displayPriority: 2),
    ];

    final sorted = eventsForDay(events, day);

    expect(sorted.map((e) => e.title).toList(), [
      'Doctor visit',
      'Night shift',
      'Lunch',
      'Soccer',
    ]);
  });

  test('multi-day all-day events span multiple days', () {
    final trip = _event(
      id: '1',
      title: 'Trip',
      startAt: DateTime.utc(2026, 8, 26),
      endAt: DateTime.utc(2026, 8, 29),
      allDay: true,
    );

    expect(eventSpansMultipleDays(trip), isTrue);
    expect(
      eventOccursOnDay(trip, DateTime(2026, 8, 27)),
      isTrue,
    );
  });

  test('layoutWeekSpans connects across columns in a week', () {
    final trip = _event(
      id: '1',
      title: 'Trip',
      startAt: DateTime.utc(2026, 8, 25),
      endAt: DateTime.utc(2026, 8, 28),
      allDay: true,
    );
    final week = List.generate(
      7,
      (index) => DateTime(2026, 8, 25 + index),
    );

    final segments = layoutWeekSpans(week, groupDuplicateEvents([trip]));

    expect(segments.length, 1);
    expect(segments.first.startColumn, 0);
    expect(segments.first.endColumn, 2);
    expect(segments.first.continuesAfter, isFalse);
    expect(segments.first.showTitle, isTrue);
  });

  test('eventChipColors uses white text on black', () {
    const surface = Colors.white;
    final colors = eventChipColors('#000000', surface);
    expect(colors.foreground, Colors.white);
    expect(colors.background, parseCalendarColor('#000000'));
  });

  test('eventChipColors uses dark text on light palette colors', () {
    const surface = Colors.white;
    for (final hex in calendarColorPalette) {
      if (hex == '#000000') continue;
      final colors = eventChipColors(hex, surface);
      expect(
        colors.foreground,
        Colors.black87,
        reason: 'expected dark text on $hex',
      );
    }
  });
}
