import 'package:dio/dio.dart';

import '../models/auth_response.dart';
import '../utils/api_endpoints.dart';
import 'api_client.dart';

class AuthException implements Exception {
  AuthException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'AuthException(code: $code, message: $message)';
}

class AuthService {
  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>? ?? {};
        return AuthResponse.fromJson(data);
      }
      throw _mapError(response);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.register,
        data: {
          'username': name,
          'email': email,
          'password': password,
          'role': role,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>? ?? {};
        return AuthResponse.fromJson(data);
      }
      throw _mapError(response);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<String> forgotPassword({required String email}) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.forgotPassword,
        data: {'email': email},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>? ?? {};
        return data['message']?.toString() ?? 'Password reset link sent.';
      }
      throw _mapError(response);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  AuthException _mapError(Response<dynamic> response) {
    final status = response.statusCode ?? 500;
    final data = response.data;
    final message = data is Map<String, dynamic>
        ? data['message']?.toString() ?? data['error']?.toString()
        : data?.toString();

    switch (status) {
      case 400:
      case 401:
        return AuthException(
          message ?? 'Invalid email or password. Please try again.',
          code: 'invalid-credentials',
        );
      case 409:
        return AuthException(
          message ?? 'This email is already registered.',
          code: 'email-exists',
        );
      case 404:
        return AuthException(
          message ?? 'No account found with that email.',
          code: 'not-found',
        );
      case 500:
      default:
        return AuthException(
          message ?? 'Something went wrong. Please try again later.',
          code: 'server-error',
        );
    }
  }

  AuthException _mapDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return AuthException(
        'No internet connection. Please check your network.',
        code: 'network-timeout',
      );
    }

    if (error.type == DioExceptionType.connectionError) {
      return AuthException(
        'No internet connection. Please check your network.',
        code: 'network-error',
      );
    }

    if (error.response != null) {
      return _mapError(error.response!);
    }

    return AuthException(
      'Something went wrong. Please try again later.',
      code: 'unknown-error',
    );
  }
}
