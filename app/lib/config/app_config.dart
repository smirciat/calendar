class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.defaultServerUrl,
    this.lockLandscape = false,
  });

  final String flavor;
  final String defaultServerUrl;
  final bool lockLandscape;

  bool get isKiosk => flavor == 'kiosk';
  bool get isMobile => flavor == 'mobile';
}
