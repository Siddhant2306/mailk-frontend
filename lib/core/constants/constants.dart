class ApiConstants {
  static const String brands = '/api/v1/brands';
  static const String externalBrands = '$brands/external';
  static const String register = '/api/v1/auth/register';
  static const String currentUser = '/api/v1/auth/me';
  static const String converters = '/api/v1/admin/converters';
  static const String converterCatalog = '/api/v1/converters';
  static const String converterImageUpload = '/api/v1/uploads/converter-image';
  static const String adminUsers = '/api/v1/admin/users';

  static const String metalHistory = '/api/v1/metals/history';

  static String converterDetail(int converterId) =>
      '$converterCatalog/$converterId';
}
