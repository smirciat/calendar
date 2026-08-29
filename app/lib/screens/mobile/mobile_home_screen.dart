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
  int _weekRows = 4;
  Timer? _pollTimer;
  final _storage = SessionStorage();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDisplaySettings();
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
      if (_tab == 1) {
        unawaited(_loadCalendars());
      }
    }
  }

  Future<void> _loadDisplaySettings() async {
    final scale = await _storage.getFontScale();
    final rows = await _storage.getMobileWeekRows();
    if (!mounted) return;
    final rowsChanged = rows != _weekRows;
    setState(() {
      _fontScale = scale;
      _weekRows = rows;
    });
    if (rowsChanged) {
      unawaited(_pollEvents());
    }
  }

  Future<void> _setFontScale(double scale) async {
    setState(() => _fontScale = scale);
    await _storage.setFontScale(scale);
  }

  Future<void> _setWeekRows(int rows) async {
    if (rows == _weekRows) return;
    setState(() => _weekRows = rows);
    await _storage.setMobileWeekRows(rows);
    await _pollEvents();
  }

  ({DateTime from, DateTime to}) _eventRange() {
    final from = DateTime.now().subtract(const Duration(days: 7));
    final to = DateTime.now().add(Duration(days: 7 * _weekRows + 7));
    return (from: from, to: to);
  }

  int _visibleWeekRows(BuildContext context) {
    return MediaQuery.orientationOf(context) == Orientation.landscape ? 2 : _weekRows;
  }

  Future<void> _loadCalendars() async {
    try {
      final calendars = await widget.api.listCalendars();
      if (!mounted) return;
      setState(() => _calendars = calendars);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
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
      final range = _eventRange();
      final events = await widget.api.getEvents(from: range.from, to: range.to);
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted && showSpinner) setState(() => _loading = false);
    }
  }

  Future<void> _pollEvents() async {
    try {
      final range = _eventRange();
      final events = await widget.api.getEvents(from: range.from, to: range.to);
      if (!mounted) return;
      setState(() => _events = events);
    } on ApiException {
      // Ignore background poll errors; manual refresh still available.
    }
  }

  Future<void> _addIcsCalendar() async {
    final connection = await showAddIcsCalendarSheet(context, api: widget.api);
    if (connection == null || !mounted) return;

    await _loadCalendars();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${connection.nickname} added — shifts sync in the background',
        ),
      ),
    );

    unawaited(_pollEvents());
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
          content: Text(
            'Complete Google sign-in in the browser, then refresh. '
            'If Google says the app is unverified, ask the admin to add your '
            'email as a test user in Google Cloud Console.',
          ),
          duration: Duration(seconds: 6),
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
    final result = await showEditCalendarSheet(
      context,
      api: widget.api,
      calendar: calendar,
    );
    if (result == null || !mounted) return;

    if (result.wasRemoved) {
      final removedId = result.removedId!;
      setState(() {
        _calendars = _calendars.where((item) => item.id != removedId).toList();
      });
      try {
        final range = _eventRange();
        final events = await widget.api.getEvents(from: range.from, to: range.to);
        if (!mounted) return;
        setState(() => _events = events);
      } on ApiException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${calendar.nickname} removed')),
      );
      return;
    }

    final updated = result.calendar!;
    setState(() {
      _calendars = _calendars
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
    });

    try {
      final range = _eventRange();
      final events = await widget.api.getEvents(from: range.from, to: range.to);
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
    final visibleWeekRows = _visibleWeekRows(context);
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final weeks = buildWeekGrid(
      anchor: DateTime.now(),
      weekCount: visibleWeekRows,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Calendar'),
        actions: [
          if (_tab == 0 && isPortrait)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _weekRows,
                  alignment: Alignment.centerRight,
                  items: const [
                    DropdownMenuItem(value: 2, child: Text('2 rows')),
                    DropdownMenuItem(value: 3, child: Text('3 rows')),
                    DropdownMenuItem(value: 4, child: Text('4 rows')),
                    DropdownMenuItem(value: 5, child: Text('5 rows')),
                  ],
                  onChanged: (value) {
                    if (value != null) _setWeekRows(value);
                  },
                ),
              ),
            ),
          IconButton(onPressed: () => _refresh(), icon: const Icon(Icons.refresh)),
          IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) {
          setState(() => _tab = index);
          if (index == 1) {
            unawaited(_loadCalendars());
          }
        },
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
                weekRowCount: visibleWeekRows,
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
                        const SizedBox(height: 16),
                        Text(
                          'Weeks on calendar',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _weekRows,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 2, child: Text('2 rows')),
                            DropdownMenuItem(value: 3, child: Text('3 rows')),
                            DropdownMenuItem(value: 4, child: Text('4 rows')),
                            DropdownMenuItem(value: 5, child: Text('5 rows')),
                          ],
                          onChanged: (value) {
                            if (value != null) _setWeekRows(value);
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Landscape always shows 2 weeks.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Linked calendars',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a calendar to change its color and nickname.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_calendars.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No calendars linked yet'),
                  )
                else
                  Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: Column(
                      children: _calendars.map(
                        (calendar) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: parseCalendarColor(calendar.color),
                          ),
                          title: Text(calendar.nickname),
                          subtitle: Text(
                            calendar.isIcs
                                ? 'Work shift feed · ${calendar.subtitle}'
                                : calendar.subtitle,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _editCalendar(calendar),
                        ),
                      ).toList(),
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
