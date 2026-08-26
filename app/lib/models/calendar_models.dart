class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.allDay,
    required this.nickname,
    required this.color,
    this.description,
    this.location,
  });

  final String id;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
  final String nickname;
  final String color;
  final String? description;
  final String? location;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String? ?? '(no title)',
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: DateTime.parse(json['end_at'] as String),
      allDay: json['all_day'] as bool? ?? false,
      nickname: json['nickname'] as String? ?? 'Calendar',
      color: json['color'] as String? ?? '#4285F4',
      description: json['description'] as String?,
      location: json['location'] as String?,
    );
  }
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
    return CalendarConnection(
      id: json['id'] as String,
      sourceType: json['source_type'] as String? ?? 'google',
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
