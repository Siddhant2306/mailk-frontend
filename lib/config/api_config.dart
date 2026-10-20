abstract final class ApiConfig {
  static const String baseUrl = 'https://malik-backend-xhnr.onrender.com';

  /// Bounds API calls that gate authentication and catalogue actions.
  static const apiConnectTimeout = Duration(seconds: 10);
  static const apiReceiveTimeout = Duration(seconds: 25);

  /// Allows one cold backend wake-up without permitting an indefinite login.
  static const sessionReceiveTimeout = Duration(seconds: 45);

  /// Firebase operations must not keep the startup UI blocked indefinitely.
  static const firebaseStartupTimeout = Duration(seconds: 20);
  static const firebaseTokenTimeout = Duration(seconds: 20);
}
