import '../config/api_config.dart';
import '../core/constants/constants.dart';
import '../models/app_user.dart';
import 'authenticated_api_client.dart';

class AuthService {
  AuthService({AuthenticatedApiClient? apiClient})
    : _apiClient = apiClient ?? AuthenticatedApiClient();

  final AuthenticatedApiClient _apiClient;

  Future<AppUser> getCurrentUser({bool allowColdStart = false}) async {
    final response = await _apiClient.get(
      ApiConstants.currentUser,
      receiveTimeout: allowColdStart ? ApiConfig.sessionReceiveTimeout : null,
    );
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Invalid current user response.');
    }
    return AppUser.fromJson(Map<String, dynamic>.from(data));
  }
}
