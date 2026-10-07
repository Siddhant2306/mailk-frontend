class ApiConstants {
  /// Supply a HTTPS API endpoint for release builds, for example with
  /// `--dart-define=API_BASE_URL=https://api.example.com`.
  ///
  /// The fallback is intended only for a backend running on the Android
  /// emulator host during local development.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String brands = '/api/v1/brands';
  static const String externalBrands = '$brands/external';
  static const String converters = '/api/v1/admin/converters';

  static const String metalHistory = '/api/v1/metals/history';
}
