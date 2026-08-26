import 'package:flutter_test/flutter_test.dart';
import 'package:family_calendar/models/calendar_models.dart';
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
}) {
  return CalendarEvent(
    id: id,
    title: title,
    startAt: startAt,
    endAt: endAt,
    allDay: allDay,
    nickname: nickname,
    color: color,
  );
}

void main() {
  test('buildWeekGrid returns requested week rows', () {
    final weeks = buildWeekGrid(anchor: DateTime(2026, 8, 26), weekCount: 5);
    expect(weeks.length, 5);
    expect(weeks.first.length, 7);
    expect(weeks.first.first.weekday, DateTime.monday);
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
}
