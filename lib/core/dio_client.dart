import 'dart:async';
import 'package:dio/dio.dart';

typedef TokenProvider = FutureOr<String?> Function();

Dio createDio(TokenProvider tokenProvider) {
  final base = const String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8000/api',
  );

  final dio = Dio(BaseOptions(
    baseUrl: base,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    contentType: 'application/json',
  ));

  // Logging แบบสั้น ๆ
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: false,
    requestHeader: false,
  ));

  // Auth header + error mapping
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      try {
        final t = await tokenProvider();
        if (t != null && t.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $t';
        }
      } catch (_) {}
      handler.next(options);
    },
    onError: (e, handler) {
      // map ข้อความให้อ่านง่าย
      final msg = switch (e.type) {
        DioExceptionType.connectionTimeout => 'Connection timeout',
        DioExceptionType.receiveTimeout => 'Receive timeout',
        DioExceptionType.sendTimeout => 'Send timeout',
        DioExceptionType.badResponse =>
          'Server error: ${e.response?.statusCode}',
        DioExceptionType.connectionError => 'Network error',
        DioExceptionType.cancel => 'Request cancelled',
        DioExceptionType.unknown => 'Unexpected error',
        _ => 'Error',
      };
      handler.next(e.copyWith(message: msg));
    },
  ));

  return dio;
}
