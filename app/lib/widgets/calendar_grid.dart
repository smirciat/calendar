import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:family_calendar/models/calendar_models.dart';
import 'package:family_calendar/utils/calendar_event_utils.dart';

class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.weeks,
    required this.events,
    required this.onDayTap,
    this.compact = false,
    this.weekRowCount = 5,
    this.fontScale = 1.0,
  });

  final List<List<DateTime>> weeks;
  final List<CalendarEvent> events;
  final void Function(DateTime day, List<CalendarEvent> dayEvents) onDayTap;
  final bool compact;
  final int weekRowCount;
  final double fontScale;

  static const _cellMargin = 2.0;

  double get _densityScale =>
      (compact ? 1.0 : (5 / weekRowCount).clamp(1.0, 2.5)) * fontScale;

  TextStyle? _scaledStyle(BuildContext context, TextStyle? base) {
    if (base == null) return null;
    return base.copyWith(fontSize: (base.fontSize ?? 14) * _densityScale);
  }

  double _eventChipHeight(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    final fontSize = (labelStyle?.fontSize ?? 11) * _densityScale;
    final lineHeight = labelStyle?.height ?? 1.0;
    const chipMargin = 2.0;
    final verticalPadding = 4 * _densityScale;
    return fontSize * lineHeight + verticalPadding + chipMargin;
  }

  int _visibleEventCount({
    required double listHeight,
    required double chipHeight,
    required int totalGroups,
    required bool reserveOverflowLine,
  }) {
    if (listHeight <= 0 || chipHeight <= 0 || totalGroups == 0) return 0;

    var maxVisible = (listHeight / chipHeight).floor();
    if (reserveOverflowLine && totalGroups > maxVisible && maxVisible > 0) {
      maxVisible -= 1;
    }
    return maxVisible.clamp(0, totalGroups);
  }

  TextStyle? _overflowStyle(BuildContext context) {
    return _scaledStyle(context, Theme.of(context).textTheme.labelSmall)?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
  }

  Color _parseColor(String hex) {
    final value = hex.replaceFirst('#', '');
    final parsed = int.parse('FF$value', radix: 16);
    return Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final headerStyle = _scaledStyle(context, Theme.of(context).textTheme.titleSmall);
    final dayNumberStyle = compact
        ? Theme.of(context).textTheme.bodyMedium
        : _scaledStyle(context, Theme.of(context).textTheme.titleMedium);
    final cellPadding = compact ? 6.0 : 6.0 * _densityScale;
    final chipHeight = _eventChipHeight(context);
    final overflowStyle = _overflowStyle(context);

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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: week.map((day) {
                    final dayEvents = eventsForDay(events, day);
                    final dayGroups = groupDuplicateEvents(dayEvents, onDay: day);
                    final isToday = DateUtils.isSameDay(day, DateTime.now());

                    return Expanded(
                      child: InkWell(
                        onTap: () => onDayTap(day, dayEvents),
                        child: Container(
                          margin: const EdgeInsets.all(_cellMargin),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isToday
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                              width: isToday ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.all(cellPadding),
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
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final maxVisible = _visibleEventCount(
                                      listHeight: constraints.maxHeight,
                                      chipHeight: chipHeight,
                                      totalGroups: dayGroups.length,
                                      reserveOverflowLine: true,
                                    );
                                    final visibleGroups =
                                        dayGroups.take(maxVisible).toList();
                                    final hiddenCount =
                                        dayGroups.length - visibleGroups.length;

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        ...visibleGroups.map(
                                          (group) => _EventChip(
                                            group: group,
                                            parseColor: _parseColor,
                                            fontScale: _densityScale,
                                          ),
                                        ),
                                        if (hiddenCount > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              '+$hiddenCount more',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: overflowStyle,
                                            ),
                                          ),
                                      ],
                                    );
                                  },
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

class _EventChip extends StatelessWidget {
  const _EventChip({
    required this.group,
    required this.parseColor,
    this.fontScale = 1.0,
  });

  final EventDisplayGroup group;
  final Color Function(String hex) parseColor;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    final event = group.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: EdgeInsets.symmetric(horizontal: 4 * fontScale, vertical: 2 * fontScale),
      decoration: BoxDecoration(
        color: parseColor(event.color).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: (Theme.of(context).textTheme.labelSmall?.fontSize ?? 11) * fontScale,
              ),
            ),
          ),
          if (group.hasDuplicates)
            Text(
              '+${group.duplicateCount}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                fontSize: (Theme.of(context).textTheme.labelSmall?.fontSize ?? 11) * fontScale,
              ),
            ),
        ],
      ),
    );
  }
}

List<List<DateTime>> buildWeekGrid({required DateTime anchor, int weekCount = 5}) {
  final sunday = weekStartSunday(anchor);
  return List.generate(weekCount, (weekIndex) {
    return List.generate(7, (dayIndex) {
      return DateTime(
        sunday.year,
        sunday.month,
        sunday.day + weekIndex * 7 + dayIndex,
      );
    });
  });
}

DateTime weekStartSunday(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday % 7));
}
