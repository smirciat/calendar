import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:family_calendar/models/calendar_models.dart';
import 'package:family_calendar/utils/calendar_event_utils.dart';

Future<void> showDayDetailSheet(
  BuildContext context,
  DateTime day,
  List<CalendarEvent> events, {
  bool kiosk = false,
}) {
  final groups = groupDuplicateEvents(events);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: kiosk ? 0.9 : 0.65,
        minChildSize: kiosk ? 0.5 : 0.35,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    DateFormat.yMMMMEEEEd().format(day),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: groups.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No events'),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            return _EventGroupTile(group: groups[index]);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _EventGroupTile extends StatefulWidget {
  const _EventGroupTile({required this.group});

  final EventDisplayGroup group;

  @override
  State<_EventGroupTile> createState() => _EventGroupTileState();
}

class _EventGroupTileState extends State<_EventGroupTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final primary = group.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: group.hasDuplicates
              ? () => setState(() => _expanded = !_expanded)
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 48,
                  margin: const EdgeInsets.only(right: 12, top: 4),
                  decoration: BoxDecoration(
                    color: _parseColor(primary.color),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              primary.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (group.hasDuplicates) ...[
                            const SizedBox(width: 8),
                            Text(
                              '+${group.duplicateCount}',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(
                              _expanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatEventTime(primary),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (!group.hasDuplicates)
                        Text(
                          primary.nickname,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (group.hasDuplicates && _expanded)
          ...group.events.skip(1).map((event) {
            return Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _parseColor(event.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      event.nickname,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          }),
        const Divider(height: 1),
      ],
    );
  }

  String _formatEventTime(CalendarEvent event) {
    if (event.allDay) return 'All day';
    final start = DateFormat.jm().format(event.startAt);
    final end = DateFormat.jm().format(event.endAt);
    return '$start – $end';
  }
}

Color _parseColor(String hex) {
  final value = hex.replaceFirst('#', '');
  final parsed = int.parse('FF$value', radix: 16);
  return Color(parsed);
}
