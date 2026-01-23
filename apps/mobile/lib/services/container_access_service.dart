/// Service for container access control operations.
///
/// Provides methods for:
/// - Locking and unlocking the robot container
/// - Fetching access logs with pagination
/// - Querying current container status
library;

import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../models/access_log.dart';
import 'api_client.dart';

/// Service for interacting with container access control endpoints.
///
/// Usage:
/// ```dart
/// final service = ContainerAccessService();
/// final status = await service.getStatus();
/// if (status.isLocked) {
///   await service.unlock(floor: 2, zone: 'A');
/// }
/// ```
class ContainerAccessService {
  ContainerAccessService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;
  static const _basePath = '/api/v1/container';

  /// Unlock the robot container.
  ///
  /// Parameters:
  /// - [location]: Human-readable location string
  /// - [floor]: Floor number (1-10)
  /// - [zone]: Zone identifier within floor
  /// - [method]: How the action was triggered (defaults to 'app')
  ///
  /// Returns the unlock response with log ID.
  ///
  /// Throws [ContainerAccessException] on failure.
  Future<LockUnlockResponse> unlock({
    String? location,
    int? floor,
    String? zone,
    String method = 'app',
  }) async {
    try {
      final response = await _dio.post(
        '$_basePath/unlock',
        data: {
          if (location != null) 'location': location,
          if (floor != null) 'floor': floor,
          if (zone != null) 'zone': zone,
          'method': method,
        },
      );
      return LockUnlockResponse.fromJson(response.data);
    } on DioException catch (e) {
      developer.log(
        'Container unlock failed',
        name: 'ContainerAccessService',
        error: e,
      );
      throw ContainerAccessException.fromDioException(e);
    }
  }

  /// Lock the robot container.
  ///
  /// Parameters:
  /// - [location]: Human-readable location string
  /// - [floor]: Floor number (1-10)
  /// - [zone]: Zone identifier within floor
  /// - [method]: How the action was triggered (defaults to 'app')
  ///
  /// Returns the lock response with log ID.
  ///
  /// Throws [ContainerAccessException] on failure.
  Future<LockUnlockResponse> lock({
    String? location,
    int? floor,
    String? zone,
    String method = 'app',
  }) async {
    try {
      final response = await _dio.post(
        '$_basePath/lock',
        data: {
          if (location != null) 'location': location,
          if (floor != null) 'floor': floor,
          if (zone != null) 'zone': zone,
          'method': method,
        },
      );
      return LockUnlockResponse.fromJson(response.data);
    } on DioException catch (e) {
      developer.log(
        'Container lock failed',
        name: 'ContainerAccessService',
        error: e,
      );
      throw ContainerAccessException.fromDioException(e);
    }
  }

  /// Get paginated access logs.
  ///
  /// Parameters:
  /// - [limit]: Maximum number of logs to return (1-100, default 50)
  /// - [offset]: Number of logs to skip (for pagination)
  /// - [action]: Filter by action type ('lock' or 'unlock')
  /// - [status]: Filter by status ('success', 'failed', 'denied')
  /// - [userId]: Filter by user ID
  ///
  /// Returns a [AccessLogsResponse] with logs and pagination info.
  Future<AccessLogsResponse> getAccessLogs({
    int limit = 50,
    int offset = 0,
    String? action,
    String? status,
    String? userId,
  }) async {
    try {
      final response = await _dio.get(
        '$_basePath/logs',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (action != null) 'action': action,
          if (status != null) 'status': status,
          if (userId != null) 'user_id': userId,
        },
      );
      return AccessLogsResponse.fromJson(response.data);
    } on DioException catch (e) {
      developer.log(
        'Get access logs failed',
        name: 'ContainerAccessService',
        error: e,
      );
      throw ContainerAccessException.fromDioException(e);
    }
  }

  /// Get a single access log by ID.
  Future<AccessLogEntry> getAccessLog(int logId) async {
    try {
      final response = await _dio.get('$_basePath/logs/$logId');
      return AccessLogEntry.fromJson(response.data);
    } on DioException catch (e) {
      developer.log(
        'Get access log failed',
        name: 'ContainerAccessService',
        error: e,
      );
      throw ContainerAccessException.fromDioException(e);
    }
  }

  /// Get current container lock status.
  ///
  /// Returns the current state from hardware, plus the last action
  /// from the database for context.
  Future<ContainerStatus> getStatus() async {
    try {
      final response = await _dio.get('$_basePath/status');
      return ContainerStatus.fromJson(response.data);
    } on DioException catch (e) {
      developer.log(
        'Get container status failed',
        name: 'ContainerAccessService',
        error: e,
      );
      throw ContainerAccessException.fromDioException(e);
    }
  }
}

/// Paginated response of access logs.
class AccessLogsResponse {
  const AccessLogsResponse({
    required this.logs,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  final List<AccessLogEntry> logs;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  factory AccessLogsResponse.fromJson(Map<String, dynamic> json) {
    return AccessLogsResponse(
      logs: (json['logs'] as List)
          .map((log) => AccessLogEntry.fromJson(log as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
      hasMore: json['has_more'] as bool,
    );
  }
}

/// Exception thrown when container access operations fail.
class ContainerAccessException implements Exception {
  const ContainerAccessException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ContainerAccessException.fromDioException(DioException e) {
    final statusCode = e.response?.statusCode;
    String message;

    if (statusCode == 401) {
      message = 'Not authenticated. Please log in again.';
    } else if (statusCode == 403) {
      message = 'Access denied. You do not have permission for this action.';
    } else if (statusCode == 503) {
      message = 'Hardware unavailable. Please try again later.';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timed out. Check your network.';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'Could not connect to server. Check your network.';
    } else {
      final detail = e.response?.data?['detail'];
      message = detail?.toString() ?? 'An unexpected error occurred.';
    }

    return ContainerAccessException(message, statusCode: statusCode);
  }

  @override
  String toString() => 'ContainerAccessException: $message';
}
