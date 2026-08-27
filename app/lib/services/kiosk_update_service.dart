import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class KioskUpdateInfo {
  KioskUpdateInfo({
    required this.versionName,
    required this.buildNumber,
    required this.apkUrl,
    required this.releaseNotes,
  });

  final String versionName;
  final int buildNumber;
  final String apkUrl;
  final String releaseNotes;

  factory KioskUpdateInfo.fromJson(Map<String, dynamic> json) {
    return KioskUpdateInfo(
      versionName: json['version_name'] as String? ?? '',
      buildNumber: json['build_number'] as int? ?? 0,
      apkUrl: json['apk_url'] as String,
      releaseNotes: json['release_notes'] as String? ?? '',
    );
  }
}

class KioskUpdateService {
  KioskUpdateService({required this.baseUrl});

  final String baseUrl;
  static const _channel = MethodChannel('family_calendar/kiosk');

  Future<PackageInfo> currentPackageInfo() => PackageInfo.fromPlatform();

  Future<KioskUpdateInfo?> checkForUpdate() async {
    if (!Platform.isAndroid) return null;

    final info = await currentPackageInfo();
    final uri = Uri.parse('$baseUrl/api/v1/kiosk/update').replace(
      queryParameters: {'build': info.buildNumber},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode == 204) return null;
    if (response.statusCode == 503) {
      final body = response.body.trim();
      if (body.isNotEmpty) {
        try {
          final json = jsonDecode(body) as Map<String, dynamic>;
          final message = json['message'] as String?;
          if (message != null && message.isNotEmpty) {
            throw Exception(message);
          }
        } catch (error) {
          if (error is Exception) rethrow;
        }
      }
      throw Exception('Server update config is incomplete.');
    }
    if (response.statusCode >= 400) {
      throw Exception('Update check failed (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return KioskUpdateInfo.fromJson(json);
  }

  Future<String> downloadApk(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 5));
    if (response.statusCode >= 400) {
      throw Exception('Download failed (${response.statusCode})');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/family-calendar-kiosk-update.apk');
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }

  Future<void> installApk(String path) async {
    await _channel.invokeMethod<void>('installApk', {'path': path});
  }
}
