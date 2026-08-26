import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:family_calendar/models/calendar_models.dart';
import 'package:family_calendar/services/api_client.dart';
import 'package:family_calendar/widgets/sheet_padding.dart';

Future<CalendarConnection?> showAddIcsCalendarSheet(
  BuildContext context, {
  required ApiClient api,
}) {
  return showModalBottomSheet<CalendarConnection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _AddIcsCalendarSheet(api: api),
  );
}

class _AddIcsCalendarSheet extends StatefulWidget {
  const _AddIcsCalendarSheet({required this.api});

  final ApiClient api;

  @override
  State<_AddIcsCalendarSheet> createState() => _AddIcsCalendarSheetState();
}

class _AddIcsCalendarSheetState extends State<_AddIcsCalendarSheet> {
  final _urlController = TextEditingController();
  final _nicknameController = TextEditingController(text: 'Work shifts');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() => _urlController.text = text);
  }

  Future<void> _submit() async {
    final feedUrl = _urlController.text.trim();
    if (feedUrl.isEmpty) {
      setState(() => _error = 'Paste the calendar sync link from the work app');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final connection = await widget.api.addIcsCalendar(
        feedUrl: feedUrl,
        nickname: _nicknameController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(connection);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Request timed out — check Settings to see if the link was saved.';
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
            'Add calendar sync link',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Paste the calendar sync or webcal link from the work scheduling app. '
            'The link is saved immediately; shifts appear within a minute.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'Calendar sync link',
              hintText: 'https://… or webcal://…',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Paste',
                onPressed: _saving ? null : _pasteFromClipboard,
                icon: const Icon(Icons.content_paste),
              ),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            enabled: !_saving,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nicknameController,
            decoration: const InputDecoration(
              labelText: 'Nickname',
              hintText: 'Cody, Work shifts…',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            enabled: !_saving,
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
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Add calendar'),
          ),
        ],
      ),
    );
  }
}
