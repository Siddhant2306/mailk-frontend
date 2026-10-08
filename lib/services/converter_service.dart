import 'package:dio/dio.dart';

import '../core/constants/constants.dart';
import '../models/converter_draft.dart';
import 'authenticated_api_client.dart';

class ConverterService {
  ConverterService({AuthenticatedApiClient? apiClient})
    : _apiClient = apiClient ?? AuthenticatedApiClient();

  final AuthenticatedApiClient _apiClient;

  Future<String> uploadConverterImage({
    required List<int> bytes,
    required String fileName,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.converterImageUpload,
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      }),
    );
    final data = response.data;
    final imageUrl = data is Map ? data['image_url'] : null;
    if (imageUrl is! String || imageUrl.trim().isEmpty) {
      throw const FormatException('Invalid converter image upload response.');
    }
    return imageUrl.trim();
  }

  Future<int> createConverter(ConverterDraft draft) async {
    final response = await _apiClient.post(
      ApiConstants.converters,
      data: draft.toJson(),
    );
    final data = response.data;
    if (data is! Map || data['converter_id'] is! int) {
      throw const FormatException('Invalid converter creation response.');
    }
    return data['converter_id'] as int;
  }

  String messageFor(Object error) {
    if (error is FormatException) {
      return 'The image service returned an invalid response. Please retry.';
    }
    if (error is AuthenticationRequiredException) {
      return 'Please sign in again before saving a converter.';
    }
    if (error is DioException) {
      if (error.response?.statusCode == 401 || error.response?.statusCode == 403) {
        return 'Admin permission is required to add converters.';
      }
      if (error.response?.statusCode == 422) {
        return 'Please correct the converter fields and try again.';
      }
      return 'Could not upload the image or save the converter. Check your connection and retry.';
    }
    return 'Could not upload the image or save the converter. Please try again.';
  }
}
