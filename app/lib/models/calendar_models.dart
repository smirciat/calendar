class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.allDay,
    required this.nickname,
    required this.color,
    this.sourceType = 'google',
    this.description,
    this.location,
    this.displayPriority,
  });

  final String id;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
  final String nickname;
  final String color;
  final String sourceType;
  final String? description;
  final String? location;
  /// Sort order from server (0 = top). See server/event-display-rules.json.
  final int? displayPriority;

  bool get isIcs => sourceType == 'ics';

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String? ?? '(no title)',
      startAt: _parseApiInstant(json['start_at'] as String),
      endAt: _parseApiInstant(json['end_at'] as String),
      allDay: json['all_day'] as bool? ?? false,
      nickname: json['nickname'] as String? ?? 'Calendar',
      color: json['color'] as String? ?? '#4285F4',
      sourceType: json['source_type'] as String? ?? 'google',
      description: json['description'] as String?,
      location: json['location'] as String?,
      displayPriority: json['display_priority'] as int?,
    );
  }
}

DateTime _parseApiInstant(String raw) {
  final parsed = DateTime.parse(raw);
  if (parsed.isUtc) return parsed;
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

class CalendarConnection {
  CalendarConnection({
    required this.id,
    required this.sourceType,
    required this.nickname,
    required this.color,
    this.googleAccountEmail,
    this.feedUrl,
  });

  final String id;
  final String sourceType;
  final String? googleAccountEmail;
  final String? feedUrl;
  final String nickname;
  final String color;

  bool get isGoogle => sourceType == 'google';
  bool get isIcs => sourceType == 'ics';

  String get subtitle {
    if (isGoogle) return googleAccountEmail ?? '';
    return _shortFeedUrl(feedUrl ?? 'Calendar sync link');
  }

  factory CalendarConnection.fromJson(Map<String, dynamic> json) {
    final sourceType =
        (json['source_type'] as String?) ??
        (json['feed_url'] != null ? 'ics' : 'google');
    return CalendarConnection(
      id: json['id'] as String,
      sourceType: sourceType,
      googleAccountEmail: json['google_account_email'] as String?,
      feedUrl: json['feed_url'] as String?,
      nickname: json['nickname'] as String? ?? 'Calendar',
      color: json['color'] as String? ?? '#4285F4',
    );
  }
}

String _shortFeedUrl(String url) {
  if (url.length <= 48) return url;
  return '${url.substring(0, 45)}…';
}
