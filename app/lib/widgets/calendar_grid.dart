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
  });

  final List<List<DateTime>> weeks;
  final List<CalendarEvent> events;
  final void Function(DateTime day, List<CalendarEvent> dayEvents) onDayTap;
  final bool compact;

  static const _cellMargin = 2.0;
  static const _laneHeight = 18.0;

  Color _parseColor(String hex) {
    final value = hex.replaceFirst('#', '');
    final parsed = int.parse('FF$value', radix: 16);
    return Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final headerStyle = Theme.of(context).textTheme.titleSmall;
    final dayNumberStyle = compact
        ? Theme.of(context).textTheme.bodyMedium
        : Theme.of(context).textTheme.titleMedium;
    final maxSpanLanes = compact ? 2 : 3;
    final maxSingleDayGroups = compact ? 2 : 4;

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
              final spanSegments = layoutWeekSpans(
                week,
                multiDayGroupsForWeek(week, events),
              );
              final laneCount = spanSegments.isEmpty
                  ? 0
                  : spanSegments.map((s) => s.lane).reduce((a, b) => a > b ? a : b) + 1;
              final visibleLaneCount = laneCount.clamp(0, maxSpanLanes);
              final spanBandHeight = visibleLaneCount * _laneHeight;

              return Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: week.map((day) {
                            final dayEvents = eventsForDay(events, day);
                            final dayGroups = groupDuplicateEvents(
                              singleDayEventsForDay(events, day),
                            );
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
                                      if (spanBandHeight > 0)
                                        SizedBox(height: spanBandHeight + 4),
                                      Expanded(
                                        child: ListView(
                                          children: dayGroups
                                              .take(maxSingleDayGroups)
                                              .map((group) => _EventChip(
                                                group: group,
                                                parseColor: _parseColor,
                                              ))
                                              .toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (spanBandHeight > 0)
                          Positioned(
                            top: 28,
                            left: 0,
                            right: 0,
                            height: spanBandHeight,
                            child: _WeekSpanLayer(
                              weekWidth: constraints.maxWidth,
                              segments: spanSegments
                                  .where((segment) => segment.lane < maxSpanLanes)
                                  .toList(),
                              laneHeight: _laneHeight,
                              cellMargin: _cellMargin,
                              parseColor: _parseColor,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _WeekSpanLayer extends StatelessWidget {
  const _WeekSpanLayer({
    required this.weekWidth,
    required this.segments,
    required this.laneHeight,
    required this.cellMargin,
    required this.parseColor,
  });

  final double weekWidth;
  final List<WeekSpanSegment> segments;
  final double laneHeight;
  final double cellMargin;
  final Color Function(String hex) parseColor;

  @override
  Widget build(BuildContext context) {
    final columnWidth = weekWidth / 7;

    return Stack(
      clipBehavior: Clip.none,
      children: segments.map((segment) {
        final left = segment.startColumn * columnWidth + cellMargin + 6;
        final width =
            (segment.endColumn - segment.startColumn + 1) * columnWidth -
            (cellMargin * 2) -
            12;
        final top = segment.lane * laneHeight;
        final event = segment.group.primary;
        final radius = Radius.circular(4);

        return Positioned(
          left: left,
          top: top,
          width: width.clamp(0, double.infinity),
          height: laneHeight - 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: parseColor(event.color).withValues(alpha: 0.35),
              borderRadius: BorderRadius.horizontal(
                left: segment.continuesBefore ? Radius.zero : radius,
                right: segment.continuesAfter ? Radius.zero : radius,
              ),
            ),
            child: segment.showTitle
                ? Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      if (segment.group.hasDuplicates)
                        Text(
                          '+${segment.group.duplicateCount}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                    ],
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _EventChip extends StatelessWidget {
  const _EventChip({
    required this.group,
    required this.parseColor,
  });

  final EventDisplayGroup group;
  final Color Function(String hex) parseColor;

  @override
  Widget build(BuildContext context) {
    final event = group.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          if (group.hasDuplicates)
            Text(
              '+${group.duplicateCount}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
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
