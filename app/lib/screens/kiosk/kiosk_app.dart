import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:family_calendar/config/app_config.dart';
import 'package:family_calendar/screens/kiosk/kiosk_calendar_screen.dart';
import 'package:family_calendar/screens/kiosk/kiosk_pairing_screen.dart';
import 'package:family_calendar/services/api_client.dart';
import 'package:family_calendar/services/session_storage.dart';

class KioskApp extends StatefulWidget {
  const KioskApp({super.key, required this.config});

  final AppConfig config;

  @override
  State<KioskApp> createState() => _KioskAppState();
}

class _KioskAppState extends State<KioskApp> {
  final _storage = SessionStorage();
  String? _deviceToken;
  String? _serverUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.config.lockLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _loadSession();
  }

  Future<void> _loadSession() async {
    final token = await _storage.getDeviceToken();
    final serverUrl =
        await _storage.getServerUrl() ?? widget.config.defaultServerUrl;
    setState(() {
      _deviceToken = token;
      _serverUrl = serverUrl;
      _loading = false;
    });
  }

  Future<void> _onPaired(String token, String serverUrl) async {
    await _storage.setDeviceToken(token);
    await _storage.setServerUrl(serverUrl);
    setState(() {
      _deviceToken = token;
      _serverUrl = serverUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Calendar Wall',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _deviceToken == null
          ? KioskPairingScreen(
              defaultServerUrl: widget.config.defaultServerUrl,
              onPaired: _onPaired,
            )
          : KioskCalendarScreen(
              api: ApiClient(baseUrl: _serverUrl!, token: _deviceToken),
            ),
    );
  }
}
