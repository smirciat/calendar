import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:family_calendar/models/calendar_models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.baseUrl, this.token});

  final String baseUrl;
  final String? token;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(
        body['error'] as String? ?? 'Request failed',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Future<bool> isRegistered() async {
    final response = await http.get(
      _uri('/api/v1/auth/status'),
      headers: _headers,
    );
    final body = await _decode(response);
    return body['registered'] as bool? ?? false;
  }

  Future<String> register({required String name, required String password}) async {
    final response = await http.post(
      _uri('/api/v1/auth/register'),
      headers: _headers,
      body: jsonEncode({'name': name, 'password': password}),
    );
    final body = await _decode(response);
    return body['token'] as String;
  }

  Future<String> login({required String password}) async {
    final response = await http.post(
      _uri('/api/v1/auth/login'),
      headers: _headers,
      body: jsonEncode({'password': password}),
    );
    final body = await _decode(response);
    return body['token'] as String;
  }

  Future<String> createPairingCode() async {
    final response = await http.post(
      _uri('/api/v1/devices/pairing-codes'),
      headers: _headers,
    );
    final body = await _decode(response);
    return body['code'] as String;
  }

  Future<String> pairDevice({required String code, String? name}) async {
    final response = await http.post(
      _uri('/api/v1/devices/pair'),
      headers: _headers,
      body: jsonEncode({'code': code, 'name': name}),
    );
    final body = await _decode(response);
    return body['token'] as String;
  }

  Future<List<CalendarConnection>> listCalendars() async {
    final response = await http.get(
      _uri('/api/v1/calendars'),
      headers: _headers,
    );
    final body = jsonDecode(response.body) as List<dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException('Failed to load calendars', statusCode: response.statusCode);
    }
    return body
        .map((item) => CalendarConnection.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CalendarConnection> updateCalendar(
    String id, {
    String? nickname,
    String? color,
  }) async {
    final response = await http.patch(
      _uri('/api/v1/calendars/$id'),
      headers: _headers,
      body: jsonEncode({
        if (nickname != null) 'nickname': nickname,
        if (color != null) 'color': color,
      }),
    );
    final body = await _decode(response);
    return CalendarConnection.fromJson(body);
  }

  Future<String> getOAuthUrl() async {
    final response = await http.get(
      _uri('/api/v1/calendars/oauth/start'),
      headers: _headers,
    );
    final body = await _decode(response);
    return body['url'] as String;
  }

  Future<List<CalendarEvent>> getEvents({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await http.get(
      _uri('/api/v1/events', {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      }),
      headers: _headers,
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        body['error'] as String? ?? 'Failed to load events',
        statusCode: response.statusCode,
      );
    }
    final body = jsonDecode(response.body) as List<dynamic>;
    return body
        .map((item) => CalendarEvent.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
