import 'package:dio/dio.dart';

/// Production-grade exception class for backend API errors from labapi.genziitian.in.
///
/// Accurately parses standard Laravel API responses:
/// - Single message errors: `{"error": "Invalid credentials"}`
/// - Validation errors: `{"message": "...", "errors": {"email": ["..."]}}`
/// - Email verification: `{"error": "...", "needs_verification": true, "email": "..."}`
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, List<String>>? validationErrors;
  final bool isUnauthorized;
  final bool needsVerification;
  final String? verificationEmail;
  final dynamic rawData;

  const ApiException({
    required this.message,
    this.statusCode,
    this.validationErrors,
    this.isUnauthorized = false,
    this.needsVerification = false,
    this.verificationEmail,
    this.rawData,
  });

  factory ApiException.fromDioException(DioException dioException) {
    final response = dioException.response;
    final statusCode = response?.statusCode;
    final dynamic data = response?.data;

    if (dioException.type == DioExceptionType.connectionTimeout ||
        dioException.type == DioExceptionType.sendTimeout ||
        dioException.type == DioExceptionType.receiveTimeout) {
      return ApiException(
        message: 'Connection timed out. Please check your internet connection.',
        statusCode: statusCode,
        rawData: data,
      );
    }

    if (dioException.type == DioExceptionType.connectionError) {
      return ApiException(
        message: 'Unable to connect to the server (labapi.genziitian.in). Please check your internet connection.',
        statusCode: statusCode,
        rawData: data,
      );
    }

    if (data is Map<String, dynamic>) {
      // 1. Check for 'error' key
      final dynamic errorField = data['error'];
      // 2. Check for 'message' key
      final dynamic messageField = data['message'];
      // 3. Check for 'needs_verification' flag
      final bool needsVerification = data['needs_verification'] == true;
      final String? verificationEmail = data['email'] as String?;

      // 4. Parse Laravel validation errors map: {"field": ["msg1", "msg2"]}
      Map<String, List<String>>? validationErrors;
      if (data['errors'] is Map) {
        final rawErrors = data['errors'] as Map<dynamic, dynamic>;
        validationErrors = rawErrors.map((key, value) {
          final list = (value is List)
              ? value.map((item) => item.toString()).toList()
              : [value.toString()];
          return MapEntry(key.toString(), list);
        });
      }

      String message = 'An unexpected error occurred.';
      if (errorField != null && errorField.toString().trim().isNotEmpty) {
        message = errorField.toString();
      } else if (messageField != null && messageField.toString().trim().isNotEmpty) {
        message = messageField.toString();
      } else if (validationErrors != null && validationErrors.isNotEmpty) {
        final firstError = validationErrors.values.first.firstOrNull;
        if (firstError != null) {
          message = firstError;
        }
      }

      return ApiException(
        message: message,
        statusCode: statusCode,
        validationErrors: validationErrors,
        isUnauthorized: statusCode == 401,
        needsVerification: needsVerification,
        verificationEmail: verificationEmail,
        rawData: data,
      );
    }

    if (data is String && data.isNotEmpty) {
      return ApiException(
        message: data,
        statusCode: statusCode,
        rawData: data,
      );
    }

    return ApiException(
      message: dioException.message ?? 'An unknown network error occurred.',
      statusCode: statusCode,
      isUnauthorized: statusCode == 401,
      rawData: data,
    );
  }

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}
