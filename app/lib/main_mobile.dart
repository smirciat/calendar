import 'package:family_calendar/app.dart';
import 'package:family_calendar/config/app_config.dart';

void main() {
  runFamilyCalendarApp(
    const AppConfig(
      flavor: 'mobile',
      defaultServerUrl: 'https://smircich.ddns.net',
    ),
  );
}
