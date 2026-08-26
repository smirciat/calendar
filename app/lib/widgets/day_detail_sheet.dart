import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:family_calendar/models/calendar_models.dart';

Future<void> showDayDetailSheet(
  BuildContext context,
  DateTime day,
  List<CalendarEvent> events,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat.yMMMMEEEEd().format(day),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (events.isEmpty)
                const Text('No events')
              else
                ...events.map((event) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(event.title),
                    subtitle: Text(
                      '${event.nickname} · ${DateFormat.jm().format(event.startAt)}',
                    ),
                  );
                }),
            ],
          ),
        ),
      );
    },
  );
}
