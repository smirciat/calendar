import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:family_calendar/models/calendar_models.dart';

class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.weeks,
    required this.events,
    required this.onDayTap,
    this.compact = false,
  });

  final List<List<DateTime>> weeks;
  final List<CalendarEvent> events;
  final void Function(DateTime day, List<CalendarEvent> dayEvents) onDayTap;
  final bool compact;

  List<CalendarEvent> _eventsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return events.where((event) {
      return event.startAt.isBefore(end) && event.endAt.isAfter(start);
    }).toList();
  }

  Color _parseColor(String hex) {
    final value = hex.replaceFirst('#', '');
    final parsed = int.parse('FF$value', radix: 16);
    return Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final headerStyle = Theme.of(context).textTheme.titleSmall;
    final dayNumberStyle = compact
        ? Theme.of(context).textTheme.bodyMedium
        : Theme.of(context).textTheme.titleMedium;

    return Column(
      children: [
        Row(
          children: dayLabels
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(label, style: headerStyle),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Column(
            children: weeks.map((week) {
              return Expanded(
                child: Row(
                  children: week.map((day) {
                    final dayEvents = _eventsForDay(day);
                    final isToday = DateUtils.isSameDay(day, DateTime.now());
                    return Expanded(
                      child: InkWell(
                        onTap: () => onDayTap(day, dayEvents),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isToday
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                              width: isToday ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat.Md().format(day),
                                style: dayNumberStyle?.copyWith(
                                  fontWeight: isToday ? FontWeight.bold : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: ListView(
                                  children: dayEvents.take(compact ? 2 : 4).map((
                                    event,
                                  ) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 2),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _parseColor(
                                          event.color,
                                        ).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        event.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

List<List<DateTime>> buildWeekGrid({required DateTime anchor, int weekCount = 5}) {
  final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
  return List.generate(weekCount, (weekIndex) {
    return List.generate(7, (dayIndex) {
      return DateTime(
        monday.year,
        monday.month,
        monday.day + weekIndex * 7 + dayIndex,
      );
    });
  });
}
