import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:family_calendar/models/calendar_models.dart';
import 'package:family_calendar/services/api_client.dart';
import 'package:family_calendar/utils/calendar_colors.dart';
import 'package:family_calendar/widgets/calendar_grid.dart';
import 'package:family_calendar/widgets/day_detail_sheet.dart';
import 'package:family_calendar/widgets/edit_calendar_sheet.dart';

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({
    super.key,
    required this.api,
    required this.onLogout,
  });

  final ApiClient api;
  final VoidCallback onLogout;

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  int _tab = 0;
  List<CalendarConnection> _calendars = [];
  List<CalendarEvent> _events = [];
  String? _pairingCode;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final calendars = await widget.api.listCalendars();
      final from = DateTime.now().subtract(const Duration(days: 7));
      final to = DateTime.now().add(const Duration(days: 28));
      final events = await widget.api.getEvents(from: from, to: to);
      if (!mounted) return;
      setState(() {
        _calendars = calendars;
        _events = events;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _linkGoogleCalendar() async {
    try {
      final url = await widget.api.getOAuthUrl();
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw ApiException('Could not open browser for Google sign-in');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete Google sign-in in the browser, then refresh.'),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _createPairingCode() async {
    try {
      final code = await widget.api.createPairingCode();
      setState(() => _pairingCode = code);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _editCalendar(CalendarConnection calendar) async {
    final updated = await showEditCalendarSheet(
      context,
      api: widget.api,
      calendar: calendar,
    );
    if (updated == null || !mounted) return;

    setState(() {
      _calendars = _calendars
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
    });

    try {
      final from = DateTime.now().subtract(const Duration(days: 7));
      final to = DateTime.now().add(const Duration(days: 28));
      final events = await widget.api.getEvents(from: from, to: to);
      if (!mounted) return;
      setState(() => _events = events);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final weeks = buildWeekGrid(anchor: DateTime.now(), weekCount: 4);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Calendar'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _tab == 0
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: CalendarGrid(
                weeks: weeks,
                events: _events,
                compact: true,
                onDayTap: (day, events) => showDayDetailSheet(context, day, events),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    title: const Text('Link Google Calendar'),
                    subtitle: const Text('Read-only access to show events'),
                    trailing: const Icon(Icons.link),
                    onTap: _linkGoogleCalendar,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wall display pairing',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Generate a code, then enter it on the wall device with the server URL.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _createPairingCode,
                          child: const Text('Generate pairing code'),
                        ),
                        if (_pairingCode != null) ...[
                          const SizedBox(height: 12),
                          SelectableText(
                            _pairingCode!,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Linked calendars', style: Theme.of(context).textTheme.titleMedium),
                if (_calendars.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No calendars linked yet'),
                  )
                else
                  ..._calendars.map(
                    (calendar) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: parseCalendarColor(calendar.color),
                      ),
                      title: Text(calendar.nickname),
                      subtitle: Text(calendar.googleAccountEmail),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editCalendar(calendar),
                    ),
                  ),
              ],
            ),
    );
  }
}
