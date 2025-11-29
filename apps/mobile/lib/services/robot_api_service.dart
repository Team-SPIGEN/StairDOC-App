import 'dart:async';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:stairdoc/models/robot_endpoint.dart';
import 'package:stairdoc/models/robot_motion_command.dart';
import '../utils/api_endpoints.dart';
import 'api_client.dart';

typedef WebSocketConnector = WebSocketChannel Function(Uri uri);

typedef WebSocketCloser = FutureOr<void> Function(WebSocketChannel channel);

class RobotControlException implements Exception {
  RobotControlException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'RobotControlException(code: $code, message: $message)';
}

class RobotApiService {
  RobotApiService({ApiClient? apiClient, WebSocketConnector? connector})
    : _apiClient = apiClient ?? ApiClient(),
      _connector = connector ?? WebSocketChannel.connect;

  final ApiClient _apiClient;
  final WebSocketConnector _connector;
  RobotEndpoint? _currentEndpoint;

  RobotEndpoint? get currentEndpoint => _currentEndpoint;

  void updateEndpoint(RobotEndpoint? endpoint) {
    _currentEndpoint = endpoint;
  }

  Future<void> sendMovementCommand(RobotMotionCommand command) async {
    try {
      final endpoint = command == RobotMotionCommand.stop
          ? ApiEndpoints.robotStop
          : ApiEndpoints.robotMotion;
      final target = _resolvePath(endpoint);
      final response = await _apiClient.dio.postUri(
        target,
        data: {'direction': command.apiValue},
      );

      if (response.statusCode == null || response.statusCode! >= 400) {
        throw RobotControlException(
          _extractMessage(response.data) ?? 'Robot rejected the command.',
          code: response.statusCode?.toString(),
        );
      }
    } on DioException catch (error) {
      throw RobotControlException(_mapDioError(error), code: error.type.name);
    } catch (error) {
      throw RobotControlException(error.toString(), code: 'unknown-error');
    }
  }

  WebSocketChannel openStatusChannel() {
    final uri =
        _currentEndpoint?.statusSocketUri ??
        ApiEndpoints.robotStatusSocketUri();
    try {
      return _connector(uri);
    } catch (error) {
      throw RobotControlException(
        'Failed to connect to status stream: $error',
        code: 'ws-connection-error',
      );
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message']?.toString() ?? data['error']?.toString();
    }
    if (data is List && data.isNotEmpty) {
      return data.first.toString();
    }
    return data?.toString();
  }

  String _mapDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Request timed out while reaching the robot.';
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Unable to reach the robot controller. Check the network connection.';
    }

    if (error.response != null) {
      final message = _extractMessage(error.response!.data);
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    return 'Unexpected error while sending command.';
  }

  Uri _resolvePath(String path) {
    final base = _currentEndpoint?.baseUrl ?? ApiEndpoints.baseUrl;
    final baseUri = Uri.parse(base.endsWith('/') ? base : '$base/');
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return baseUri.resolve(normalizedPath);
  }
}
