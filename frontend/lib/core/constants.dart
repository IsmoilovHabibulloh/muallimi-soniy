/// API configuration constants.
class AppConstants {
  AppConstants._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ikkinchimuallim.codingtech.uz/api/v1',
  );

  static const String mediaBaseUrl = String.fromEnvironment(
    'MEDIA_BASE_URL',
    defaultValue: 'https://ikkinchimuallim.codingtech.uz/media',
  );

  static const Duration manifestPollInterval = Duration(seconds: 45);
  static const Duration apiTimeout = Duration(seconds: 30);

  // Storage keys
  static const String keyConsent = 'consent_accepted';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLocale = 'locale';
  static const String keyManifestVersion = 'manifest_version';
  static const String keyLastReadPage = 'last_read_page';
}
