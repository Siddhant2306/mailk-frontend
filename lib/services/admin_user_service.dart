import 'package:dio/dio.dart';

import '../core/constants/constants.dart';
import '../models/pending_user.dart';
import 'authenticated_api_client.dart';

class AdminUserService {
  AdminUserService({AuthenticatedApiClient? apiClient})
    : _apiClient = apiClient ?? AuthenticatedApiClient();

  final AuthenticatedApiClient _apiClient;

  Future<List<PendingUser>> getPendingUsers() async {
    final response = await _apiClient.get(ApiConstants.adminUsers);
    return PendingUser.pendingFromResponse(response.data);
  }

  Future<void> approveUser(int userId) async {
    await _apiClient.post('${ApiConstants.adminUsers}/$userId/approve');
  }

  Future<void> rejectUser(int userId) async {
    await _apiClient.post('${ApiConstants.adminUsers}/$userId/reject');
  }

  String messageFor(Object error) {
    if (error is AuthenticationRequiredException) {
      return 'Please sign in again to manage approvals.';
    }
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        return 'Admin permission is required to manage approvals.';
      }
      return 'Could not update the approval queue. Check your connection and retry.';
    }
    if (error is FormatException) {
      return 'The server returned an invalid user list.';
    }
    return 'Could not update the approval queue. Please try again.';
  }
}
