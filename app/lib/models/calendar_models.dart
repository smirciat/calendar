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
    required this.googleAccountEmail,
    required this.nickname,
    required this.color,
  });

  final String id;
  final String googleAccountEmail;
  final String nickname;
  final String color;

  factory CalendarConnection.fromJson(Map<String, dynamic> json) {
    return CalendarConnection(
      id: json['id'] as String,
      googleAccountEmail: json['google_account_email'] as String,
      nickname: json['nickname'] as String? ?? 'Calendar',
      color: json['color'] as String? ?? '#4285F4',
    );
  }
}
