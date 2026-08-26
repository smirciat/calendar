import 'package:flutter/material.dart';

import 'package:family_calendar/config/app_config.dart';
import 'package:family_calendar/screens/mobile/login_screen.dart';
import 'package:family_calendar/screens/mobile/mobile_home_screen.dart';
import 'package:family_calendar/services/api_client.dart';
import 'package:family_calendar/services/session_storage.dart';

class MobileApp extends StatefulWidget {
  const MobileApp({super.key, required this.config});

  final AppConfig config;

  @override
  State<MobileApp> createState() => _MobileAppState();
}

class _MobileAppState extends State<MobileApp> {
  final _storage = SessionStorage();
  String? _token;
  String? _serverUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final token = await _storage.getFamilyToken();
    final serverUrl =
        await _storage.getServerUrl() ?? widget.config.defaultServerUrl;
    setState(() {
      _token = token;
      _serverUrl = serverUrl;
      _loading = false;
    });
  }

  Future<void> _onAuthenticated(String token, String serverUrl) async {
    await _storage.setFamilyToken(token);
    await _storage.setServerUrl(serverUrl);
    setState(() {
      _token = token;
      _serverUrl = serverUrl;
    });
  }

  Future<void> _logout() async {
    await _storage.clearFamilyToken();
    setState(() => _token = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Calendar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _token == null
          ? LoginScreen(
              defaultServerUrl: widget.config.defaultServerUrl,
              onAuthenticated: _onAuthenticated,
            )
          : MobileHomeScreen(
              api: ApiClient(baseUrl: _serverUrl!, token: _token),
              onLogout: _logout,
            ),
    );
  }
}
