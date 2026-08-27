import 'dart:async';

import 'package:flutter/material.dart';

import 'package:family_calendar/models/calendar_models.dart';
import 'package:family_calendar/services/api_client.dart';
import 'package:family_calendar/services/kiosk_update_service.dart';
import 'package:family_calendar/services/session_storage.dart';
import 'package:family_calendar/utils/calendar_event_utils.dart';
import 'package:family_calendar/widgets/calendar_grid.dart';
import 'package:family_calendar/widgets/day_detail_sheet.dart';
import 'package:family_calendar/widgets/kiosk_admin_sheet.dart';

class KioskCalendarScreen extends StatefulWidget {
  const KioskCalendarScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<KioskCalendarScreen> createState() => _KioskCalendarScreenState();
}

class _KioskCalendarScreenState extends State<KioskCalendarScreen>
    with WidgetsBindingObserver {
  static const _idleTimeout = Duration(minutes: 2);

  DateTime _anchor = DateTime.now();
  List<CalendarEvent> _events = [];
  bool _eventsLoading = true;
  String? _error;
  int _weekRows = 5;
  double _fontScale = 1.0;
  final _storage = SessionStorage();
  Timer? _idleTimer;
  Timer? _clockSyncTimer;
  Timer? _pollTimer;
  bool _initialAnchorChecked = false;
  int _adminTapCount = 0;
  Timer? _adminTapTimer;
  bool _adminSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAnchorToNow());
    _loadDisplaySettings();
    _clockSyncTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      _syncAnchorToNow(reloadEvents: true);
    });
    _pollTimer = Timer.periodic(calendarEventPollInterval, (_) {
      if (!mounted) return;
      _loadEvents(silent: true);
    });
    _loadEvents();
    _resetIdleTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _clockSyncTimer?.cancel();
    _pollTimer?.cancel();
    _adminTapTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncAnchorToNow(reloadEvents: true);
    }
  }

  Future<void> _loadDisplaySettings() async {
    final rows = await _storage.getKioskWeekRows();
    final fontScale = await _storage.getFontScale();
    if (!mounted) return;
    final rowsChanged = rows != _weekRows;
    setState(() {
      _weekRows = rows;
      _fontScale = fontScale;
    });
    if (rowsChanged) {
      _loadEvents();
    }
  }

  Future<void> _setWeekRows(int rows) async {
    if (rows == _weekRows) return;
    _onUserInteraction();
    setState(() => _weekRows = rows);
    await _storage.setKioskWeekRows(rows);
    _loadEvents();
  }

  Future<void> _setFontScale(double scale) async {
    if (scale == _fontScale) return;
    _onUserInteraction();
    setState(() => _fontScale = scale);
    await _storage.setFontScale(scale);
  }

  void _syncAnchorToNow({bool reloadEvents = false}) {
    final now = DateTime.now();
    final needsUpdate = !_isSameWeek(_anchor, now);
    if (needsUpdate || !_initialAnchorChecked) {
      _initialAnchorChecked = true;
      if (needsUpdate) {
        setState(() => _anchor = now);
      }
      if (needsUpdate || reloadEvents) {
        _loadEvents();
      }
    } else {
      _initialAnchorChecked = true;
    }
  }

  bool _isSameWeek(DateTime a, DateTime b) {
    return DateUtils.isSameDay(weekStartSunday(a), weekStartSunday(b));
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      if (!mounted) return;
      setState(() => _anchor = DateTime.now());
      _loadEvents();
    });
  }

  void _onUserInteraction() {
    _resetIdleTimer();
  }

  Future<void> _loadEvents({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _eventsLoading = true;
        _error = null;
      });
    }
    try {
      final from = _anchor.subtract(const Duration(days: 7));
      final to = _anchor.add(Duration(days: 7 * _weekRows + 7));
      final events = await widget.api.getEvents(from: from, to: to);
      if (!mounted) return;
      setState(() => _events = events);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (!silent) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && !silent) setState(() => _eventsLoading = false);
    }
  }

  void _shiftWeeks(int delta) {
    _onUserInteraction();
    setState(() {
      _anchor = _anchor.add(Duration(days: 7 * delta));
    });
    _loadEvents();
  }

  void _goToToday() {
    _onUserInteraction();
    setState(() => _anchor = DateTime.now());
    _loadEvents();
  }

  void _onAdminTitleTap() {
    if (_adminSheetOpen) return;
    _onUserInteraction();
    _adminTapTimer?.cancel();
    _adminTapCount++;
    if (_adminTapCount >= 7) {
      _adminTapCount = 0;
      _openAdminSheet();
      return;
    }
    _adminTapTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _adminTapCount = 0);
    });
  }

  Future<void> _openAdminSheet() async {
    if (_adminSheetOpen || !mounted) return;
    setState(() => _adminSheetOpen = true);
    try {
      await showKioskAdminSheet(
        context,
        updateService: KioskUpdateService(baseUrl: widget.api.baseUrl),
      );
    } finally {
      if (mounted) setState(() => _adminSheetOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weeks = buildWeekGrid(anchor: _anchor, weekCount: _weekRows);

    return Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onAdminTitleTap,
            child: const Text('Family Calendar'),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<double>(
                  value: _nearestFontScaleOption(_fontScale),
                  alignment: Alignment.centerRight,
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
              ),
            ),
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
            if (_eventsLoading)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            IconButton(
              onPressed: () => _shiftWeeks(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: _goToToday,
              icon: const Icon(Icons.today),
            ),
            IconButton(
              onPressed: () => _shiftWeeks(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _onUserInteraction,
          onPanDown: (_) => _onUserInteraction(),
          child: _error != null
              ? Center(child: Text(_error!))
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: CalendarGrid(
                    weeks: weeks,
                    events: _events,
                    weekRowCount: _weekRows,
                    fontScale: _fontScale,
                    onDayTap: (day, events) {
                      _onUserInteraction();
                      showDayDetailSheet(
                        context,
                        day,
                        events,
                        kiosk: true,
                        fontScale: _fontScale,
                      );
                    },
                  ),
                ),
        ),
    );
  }
}

double _nearestFontScaleOption(double scale) {
  return calendarFontScaleOptions.reduce(
    (a, b) => (a - scale).abs() <= (b - scale).abs() ? a : b,
  );
}
