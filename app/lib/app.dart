import 'package:flutter/material.dart';
import 'package:family_calendar/config/app_config.dart';
import 'package:family_calendar/screens/kiosk/kiosk_app.dart';
import 'package:family_calendar/screens/mobile/mobile_app.dart';

void runFamilyCalendarApp(AppConfig config) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(config.isKiosk ? KioskApp(config: config) : MobileApp(config: config));
}
