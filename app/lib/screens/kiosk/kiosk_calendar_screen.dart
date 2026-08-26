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

class _KioskCalendarScreenState extends State<KioskCalendarScreen> {
  static const _idleTimeout = Duration(minutes: 2);

  DateTime _anchor = DateTime.now();
  List<CalendarEvent> _events = [];
  bool _loading = true;
  String? _error;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
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
      _loading = true;
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
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shiftWeeks(int delta) {
    _onUserInteraction();
    setState(() {
      _anchor = _anchor.add(Duration(days: 7 * delta));
    });
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
            IconButton(
              onPressed: () => _shiftWeeks(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: () {
                setState(() => _anchor = DateTime.now());
                _loadEvents();
              },
              icon: const Icon(Icons.today),
            ),
            IconButton(
              onPressed: () => _shiftWeeks(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : Padding(
                padding: const EdgeInsets.all(12),
                child: CalendarGrid(
                  weeks: weeks,
                  events: _events,
                  onDayTap: (day, events) {
                    _onUserInteraction();
                    showDayDetailSheet(context, day, events);
                  },
                ),
              ),
      ),
    );
  }
}
