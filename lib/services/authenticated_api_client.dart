import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/api_config.dart';

/// Builds API requests with a fresh Firebase ID token.
///
/// The server remains the authority for authorization; the token merely
/// identifies the signed-in user to it.
class AuthenticatedApiClient {
  AuthenticatedApiClient({Dio? dio, FirebaseAuth? firebaseAuth})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 25),
              responseType: ResponseType.json,
            ),
          ),
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final Dio _dio;
  final FirebaseAuth _firebaseAuth;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: await createAuthorizedOptions(),
    );
  }

  Future<Response<dynamic>> post(String path, {Object? data}) async {
    final options = await createAuthorizedOptions();
    if (data == null) {
      return _dio.post(path, options: options);
    }
    return _dio.post(path, data: data, options: options);
  }

  Future<Response<dynamic>> patch(String path, {Object? data}) async {
    return _dio.patch(
      path,
      data: data,
      options: await createAuthorizedOptions(),
    );
  }

  Future<Response<dynamic>> delete(String path) async {
    return _dio.delete(path, options: await createAuthorizedOptions());
  }

  Future<Options> createAuthorizedOptions() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthenticationRequiredException();
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const AuthenticationRequiredException();
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }
}

class AuthenticationRequiredException implements Exception {
  const AuthenticationRequiredException();
}
