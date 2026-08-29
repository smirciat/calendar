import 'package:flutter/material.dart';

import 'package:family_calendar/models/calendar_models.dart';
import 'package:family_calendar/services/api_client.dart';
import 'package:family_calendar/utils/calendar_colors.dart';
import 'package:family_calendar/widgets/sheet_padding.dart';

class EditCalendarSheetResult {
  const EditCalendarSheetResult._({this.calendar, this.removedId});

  const EditCalendarSheetResult.updated(CalendarConnection calendar)
    : this._(calendar: calendar);

  const EditCalendarSheetResult.removed(String removedId)
    : this._(removedId: removedId);

  final CalendarConnection? calendar;
  final String? removedId;

  bool get wasRemoved => removedId != null;
}

Future<EditCalendarSheetResult?> showEditCalendarSheet(
  BuildContext context, {
  required ApiClient api,
  required CalendarConnection calendar,
}) {
  return showModalBottomSheet<EditCalendarSheetResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return _EditCalendarSheet(api: api, calendar: calendar);
    },
  );
}

class _EditCalendarSheet extends StatefulWidget {
  const _EditCalendarSheet({required this.api, required this.calendar});

  final ApiClient api;
  final CalendarConnection calendar;

  @override
  State<_EditCalendarSheet> createState() => _EditCalendarSheetState();
}

class _EditCalendarSheetState extends State<_EditCalendarSheet> {
  late final TextEditingController _nicknameController;
  late String _selectedColor;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.calendar.nickname);
    _selectedColor = widget.calendar.color;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      setState(() => _error = 'Nickname is required');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final updated = await widget.api.updateCalendar(
        widget.calendar.id,
        nickname: nickname,
        color: _selectedColor,
      );
      if (!mounted) return;
      Navigator.of(context).pop(EditCalendarSheetResult.updated(updated));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  Future<void> _confirmRemove() async {
    final calendar = widget.calendar;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove calendar?'),
        content: Text(
          calendar.isIcs
              ? 'Remove "${calendar.nickname}" from the family calendar? '
                    'Synced events from this link will disappear from the wall.'
              : 'Remove "${calendar.nickname}" (${calendar.subtitle}) from the '
                    'family calendar? Events will stop syncing. You can link '
                    'this Google account again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Remove',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.api.deleteCalendar(calendar.id);
      if (!mounted) return;
      Navigator.of(context).pop(EditCalendarSheetResult.removed(calendar.id));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: modalSheetPadding(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Calendar color & nickname',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            widget.calendar.subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nicknameController,
            decoration: const InputDecoration(
              labelText: 'Nickname',
              hintText: 'Dad, Mom, Cody…',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            enabled: !_busy,
          ),
          const SizedBox(height: 16),
          Text('Color', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: calendarColorPalette.map((hex) {
              final selected = hex == _selectedColor;
              return InkWell(
                onTap: _busy ? null : () => setState(() => _selectedColor = hex),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: parseCalendarColor(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.onSurface
                          : hex == '#000000'
                          ? Theme.of(context).dividerColor
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check,
                          color: swatchCheckColor(hex),
                          size: 20,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : _confirmRemove,
            child: Text(
              'Remove calendar',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
