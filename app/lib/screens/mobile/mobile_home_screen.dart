import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:family_calendar/models/calendar_models.dart';
import 'package:family_calendar/services/api_client.dart';
import 'package:family_calendar/services/session_storage.dart';
import 'package:family_calendar/utils/calendar_colors.dart';
import 'package:family_calendar/utils/calendar_event_utils.dart';
import 'package:family_calendar/widgets/add_ics_calendar_sheet.dart';
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

class _MobileHomeScreenState extends State<MobileHomeScreen>
    with WidgetsBindingObserver {
  int _tab = 0;
  List<CalendarConnection> _calendars = [];
  List<CalendarEvent> _events = [];
  String? _pairingCode;
  bool _loading = true;
  String? _error;
  double _fontScale = 1.0;
  Timer? _pollTimer;
  final _storage = SessionStorage();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFontScale();
    _refresh(showSpinner: true);
    _pollTimer = Timer.periodic(calendarEventPollInterval, (_) {
      _pollEvents();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pollEvents();
    }
  }

  Future<void> _loadFontScale() async {
    final scale = await _storage.getFontScale();
    if (!mounted) return;
    setState(() => _fontScale = scale);
  }

  Future<void> _setFontScale(double scale) async {
    setState(() => _fontScale = scale);
    await _storage.setFontScale(scale);
  }

  Future<void> _refresh({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final calendars = await widget.api.listCalendars();
      final from = DateTime.now().subtract(const Duration(days: 7));
      final to = DateTime.now().add(const Duration(days: 28));
      final events = await widget.api.getEvents(from: from, to: to);
      if (!mounted) return;
      setState(() {
        _calendars = calendars;
        _events = events;
        if (showSpinner) _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (showSpinner) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && showSpinner) setState(() => _loading = false);
    }
  }

  Future<void> _pollEvents() async {
    try {
      final from = DateTime.now().subtract(const Duration(days: 7));
      final to = DateTime.now().add(const Duration(days: 28));
      final events = await widget.api.getEvents(from: from, to: to);
      if (!mounted) return;
      setState(() => _events = events);
    } on ApiException {
      // Ignore background poll errors; manual refresh still available.
    }
  }

  Future<void> _addIcsCalendar() async {
    final connection = await showAddIcsCalendarSheet(context, api: widget.api);
    if (connection == null || !mounted) return;

    setState(() {
      _calendars = [..._calendars, connection];
    });

    try {
      final from = DateTime.now().subtract(const Duration(days: 7));
      final to = DateTime.now().add(const Duration(days: 28));
      final events = await widget.api.getEvents(from: from, to: to);
      if (!mounted) return;
      setState(() => _events = events);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${connection.nickname} calendar added')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
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
          IconButton(onPressed: () => _refresh(), icon: const Icon(Icons.refresh)),
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
                fontScale: _fontScale,
                onDayTap: (day, events) => showDayDetailSheet(
                  context,
                  day,
                  events,
                  fontScale: _fontScale,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Text size',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<double>(
                          value: _nearestFontScaleOption(_fontScale),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          items: calendarFontScaleOptions
                              .map(
                                (scale) => DropdownMenuItem(
                                  value: scale,
                                  child: Text(fontScaleLabel(scale)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) _setFontScale(value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    title: const Text('Add calendar sync link'),
                    subtitle: const Text('Work shift feeds (ICS / webcal)'),
                    trailing: const Icon(Icons.event_repeat),
                    onTap: _addIcsCalendar,
                  ),
                ),
                const SizedBox(height: 12),
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
                      subtitle: Text(calendar.subtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editCalendar(calendar),
                    ),
                  ),
              ],
            ),
    );
  }
}

double _nearestFontScaleOption(double scale) {
  return calendarFontScaleOptions.reduce(
    (a, b) => (a - scale).abs() <= (b - scale).abs() ? a : b,
  );
}
