import 'dart:async';

import 'package:flutter/material.dart';

import 'package:family_calendar/models/calendar_models.dart';
import 'package:family_calendar/services/api_client.dart';
import 'package:family_calendar/widgets/calendar_grid.dart';
import 'package:family_calendar/widgets/day_detail_sheet.dart';

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
  Timer? _idleTimer;
  Timer? _clockSyncTimer;
  bool _initialAnchorChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAnchorToNow());
    _clockSyncTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      _syncAnchorToNow(reloadEvents: true);
    });
    _loadEvents();
    _resetIdleTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _clockSyncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncAnchorToNow(reloadEvents: true);
    }
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
    final mondayA = a.subtract(Duration(days: a.weekday - 1));
    final mondayB = b.subtract(Duration(days: b.weekday - 1));
    return DateUtils.isSameDay(mondayA, mondayB);
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

  Future<void> _loadEvents() async {
    setState(() {
      _eventsLoading = true;
      _error = null;
    });
    try {
      final from = _anchor.subtract(const Duration(days: 7));
      final to = _anchor.add(const Duration(days: 35));
      final events = await widget.api.getEvents(from: from, to: to);
      if (!mounted) return;
      setState(() => _events = events);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _eventsLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final weeks = buildWeekGrid(anchor: _anchor);

    return GestureDetector(
      onTap: _onUserInteraction,
      onPanDown: (_) => _onUserInteraction(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Family Calendar'),
          actions: [
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
        body: _error != null
            ? Center(child: Text(_error!))
            : Padding(
                padding: const EdgeInsets.all(12),
                child: CalendarGrid(
                  weeks: weeks,
                  events: _events,
                  onDayTap: (day, events) {
                    _onUserInteraction();
                    showDayDetailSheet(
                      context,
                      day,
                      events,
                      kiosk: true,
                    );
                  },
                ),
              ),
      ),
    );
  }
}
