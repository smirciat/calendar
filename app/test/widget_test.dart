import 'package:flutter_test/flutter_test.dart';
import 'package:family_calendar/widgets/calendar_grid.dart';

void main() {
  test('buildWeekGrid returns requested week rows', () {
    final weeks = buildWeekGrid(anchor: DateTime(2026, 8, 26), weekCount: 5);
    expect(weeks.length, 5);
    expect(weeks.first.length, 7);
    expect(weeks.first.first.weekday, DateTime.monday);
  });
}
