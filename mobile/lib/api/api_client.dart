import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_exceptions.dart';
import 'cdn_debug_capture.dart';
import '../state/app_activity.dart';

/// Production-grade API client connecting directly to https://labapi.genziitian.in.
///
/// Principles:
/// - The server remains authoritative for account data and quiz scoring.
/// - Sanctum tokens and downloaded paper drafts are stored with platform secure storage.
/// - Safe GET requests retry briefly after transient network/server failures.
/// - Automatic Sanctum Bearer token header injection on every authenticated request.
class ApiClient {
  static const String defaultBaseUrl =
      'https://labapi.genziitian.in/public/api';
  static const String tokenStorageKey = 'auth_token';
  static const String cachedUserKey = 'auth_user_cache';
  static final ValueNotifier<bool> connectionUnavailable = ValueNotifier(false);

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  void Function()? onUnauthorized;

  ApiClient({
    String baseUrl = defaultBaseUrl,
    FlutterSecureStorage? secureStorage,
    this.onUnauthorized,
    List<Interceptor>? additionalInterceptors,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl.endsWith('/')
               ? baseUrl.substring(0, baseUrl.length - 1)
               : baseUrl,
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 20),
           sendTimeout: const Duration(seconds: 15),
           headers: {
             'Accept': 'application/json',
             'Content-Type': 'application/json',
             'X-QuizLab-Client': 'mobile',
           },
         ),
       ) {
    _dio.interceptors.add(
      _SanctumAuthInterceptor(
        secureStorage: _secureStorage,
        onUnauthorized: () {
          onUnauthorized?.call();
        },
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (kDebugMode &&
              RegExp(
                r'/(courses|student/uploaded-papers|student/spin-practice(?:/quota)?)$',
              ).hasMatch(options.uri.path)) {
            debugPrint(
              'Quiz LAB API start: ${options.method} ${options.uri.path} timeUtc=${DateTime.now().toUtc().toIso8601String()} url=${options.uri.origin}${options.uri.path}',
            );
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode &&
              RegExp(
                r'/(courses|student/uploaded-papers|student/spin-practice(?:/quota)?)$',
              ).hasMatch(response.requestOptions.uri.path)) {
            // Confirm recovery using metadata only, never account data or tokens.
            debugPrint(
              'Quiz LAB API: ${response.requestOptions.method} '
              '${response.requestOptions.uri.path} '
              'status=${response.statusCode} '
              'contentType=${response.headers.value('content-type') ?? 'unknown'} '
              'requestId=${response.headers.value('x-hcdn-request-id') ?? 'none'} '
              'timeUtc=${DateTime.now().toUtc().toIso8601String()} '
              'url=${response.requestOptions.uri.origin}${response.requestOptions.uri.path} '
              'cacheStatus=${response.headers.value('x-hcdn-cache-status') ?? 'absent'}',
            );
          }
          connectionUnavailable.value = false;
          handler.next(response);
        },
        onError: (error, handler) {
          if (kDebugMode && error.type != DioExceptionType.cancel) {
            final response = error.response;
            final body = response?.data;
            if (response?.statusCode == 403 &&
                body is String &&
                (response?.headers.value('content-type') ?? '').contains(
                  'text/html',
                ) &&
                response?.headers.value('x-hcdn-request-id') != null &&
                body.toLowerCase().contains('checking your browser')) {
              unawaited(
                saveCdnDebugCapture(
                  body: body,
                  requestId: response!.headers.value('x-hcdn-request-id')!,
                  method: error.requestOptions.method,
                  path: error.requestOptions.uri.path,
                  url:
                      '${error.requestOptions.uri.origin}${error.requestOptions.uri.path}',
                ),
              );
            }
            // Diagnostic metadata only: never log tokens, query strings or bodies.
            debugPrint(
              'Quiz LAB API: ${error.requestOptions.method} '
              '${error.requestOptions.uri.path} '
              'status=${response?.statusCode ?? error.type.name} '
              'contentType=${response?.headers.value('content-type') ?? 'unknown'} '
              'requestId=${response?.headers.value('x-hcdn-request-id') ?? 'none'} '
              'timeUtc=${DateTime.now().toUtc().toIso8601String()} '
              'url=${error.requestOptions.uri.origin}${error.requestOptions.uri.path} '
              'cacheStatus=${response?.headers.value('x-hcdn-cache-status') ?? 'absent'}',
            );
          }
          if (error.type != DioExceptionType.cancel) {
            connectionUnavailable.value =
                error.response == null;
          }
          handler.next(error);
        },
      ),
    );

    if (additionalInterceptors != null) {
      _dio.interceptors.addAll(additionalInterceptors);
    }
  }

  Dio get dio => _dio;
  FlutterSecureStorage get secureStorage => _secureStorage;

  // ---------------------------------------------------------------------------
  // Sanctum Token Management (Sole Client-Side Persistent State)
  // ---------------------------------------------------------------------------

  Future<void> saveAuthToken(String token) async {
    await _secureStorage.write(key: tokenStorageKey, value: token);
  }

  Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: tokenStorageKey);
  }

  Future<void> deleteAuthToken() async {
    await _secureStorage.delete(key: tokenStorageKey);
  }

  Future<void> saveCachedUser(String json) =>
      _secureStorage.write(key: cachedUserKey, value: json);

  Future<String?> getCachedUser() => _secureStorage.read(key: cachedUserKey);

  Future<void> deleteCachedUser() => _secureStorage.delete(key: cachedUserKey);

  Future<bool> hasAuthToken() async {
    final token = await getAuthToken();
    return token != null && token.trim().isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Core HTTP Execution with Standardized Error Mapping
  // ---------------------------------------------------------------------------

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final finish = AppActivity.request(path, 'GET', extra: options?.extra);
    try {
      for (var attempt = 0; ; attempt++) {
        try {
          return await _dio.get<T>(
            path,
            queryParameters: queryParameters,
            options: options,
            cancelToken: cancelToken,
          );
        } on DioException catch (e) {
          final status = e.response?.statusCode;
          final transient =
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError ||
              status == 408 ||
              status == 502 ||
              status == 503 ||
              status == 504;
          if (!transient || attempt >= 2 || cancelToken?.isCancelled == true) {
            throw ApiException.fromDioException(e);
          }
          await Future<void>.delayed(
            Duration(milliseconds: attempt == 0 ? 300 : 900),
          );
        }
      }
    } finally {
      finish();
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final finish = AppActivity.request(path, 'POST', extra: options?.extra);
    try {
      try {
        return await _dio.post<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        );
      } on DioException catch (e) {
        throw ApiException.fromDioException(e);
      }
    } finally {
      finish();
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final finish = AppActivity.request(path, 'PUT', extra: options?.extra);
    try {
      try {
        return await _dio.put<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        );
      } on DioException catch (e) {
        throw ApiException.fromDioException(e);
      }
    } finally {
      finish();
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final finish = AppActivity.request(path, 'PATCH', extra: options?.extra);
    try {
      try {
        return await _dio.patch<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        );
      } on DioException catch (e) {
        throw ApiException.fromDioException(e);
      }
    } finally {
      finish();
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final finish = AppActivity.request(path, 'DELETE', extra: options?.extra);
    try {
      try {
        return await _dio.delete<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        );
      } on DioException catch (e) {
        throw ApiException.fromDioException(e);
      }
    } finally {
      finish();
    }
  }
}

/// Dio Interceptor that injects Sanctum Personal Access Token into all requests.
class _SanctumAuthInterceptor extends Interceptor {
  final FlutterSecureStorage secureStorage;
  final void Function() onUnauthorized;

  _SanctumAuthInterceptor({
    required this.secureStorage,
    required this.onUnauthorized,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await secureStorage.read(key: ApiClient.tokenStorageKey);
    if (token != null && token.trim().isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept'] = 'application/json';
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Sanctum token is revoked, invalid, or expired.
      secureStorage.delete(key: ApiClient.tokenStorageKey);
      onUnauthorized();
    }
    return handler.next(err);
  }
}
