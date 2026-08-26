import 'package:flutter/material.dart';

import 'package:family_calendar/models/calendar_models.dart';
import 'package:family_calendar/services/api_client.dart';
import 'package:family_calendar/utils/calendar_colors.dart';

Future<CalendarConnection?> showEditCalendarSheet(
  BuildContext context, {
  required ApiClient api,
  required CalendarConnection calendar,
}) {
  return showModalBottomSheet<CalendarConnection>(
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
  bool _saving = false;
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
      _saving = true;
      _error = null;
    });

    try {
      final updated = await widget.api.updateCalendar(
        widget.calendar.id,
        nickname: nickname,
        color: _selectedColor,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
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
            enabled: !_saving,
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
                onTap: _saving ? null : () => setState(() => _selectedColor = hex),
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
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
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
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
