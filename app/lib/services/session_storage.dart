import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const _serverUrlKey = 'server_url';
  static const _familyTokenKey = 'family_token';
  static const _deviceTokenKey = 'device_token';

  Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey);
  }

  Future<void> setServerUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, value);
  }

  Future<String?> getFamilyToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_familyTokenKey);
  }

  Future<void> setFamilyToken(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_familyTokenKey, value);
  }

  Future<void> clearFamilyToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_familyTokenKey);
  }

  Future<String?> getDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceTokenKey);
  }

  Future<void> setDeviceToken(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceTokenKey, value);
  }

  Future<void> clearDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceTokenKey);
  }
}
