/// WebSocket service for real-time telemetry streaming.
///
/// Provides:
/// - Auto-reconnection with exponential backoff
/// - Connection state management
/// - Stream-based telemetry updates
/// - Subscription management
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/telemetry.dart';
import '../utils/api_endpoints.dart';

/// Connection state for WebSocket.
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// WebSocket service for telemetry streaming.
///
/// Usage:
/// ```dart
/// final service = TelemetryWebSocketService();
/// service.telemetryStream.listen((data) => print(data));
/// await service.connect();
/// ```
class TelemetryWebSocketService {
  TelemetryWebSocketService({
    String? baseUrl,
    this.autoReconnect = true,
    this.maxReconnectAttempts = 10,
    this.initialReconnectDelay = const Duration(seconds: 1),
    this.maxReconnectDelay = const Duration(seconds: 30),
  }) : _baseUrl = baseUrl ?? ApiEndpoints.wsBaseUrl;

  final String _baseUrl;
  final bool autoReconnect;
  final int maxReconnectAttempts;
  final Duration initialReconnectDelay;
  final Duration maxReconnectDelay;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  // Connection state
  final _connectionStateController =
      StreamController<WebSocketConnectionState>.broadcast();
  WebSocketConnectionState _connectionState =
      WebSocketConnectionState.disconnected;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  // Telemetry stream
  final _telemetryController = StreamController<TelemetryData>.broadcast();

  // Error stream
  final _errorController = StreamController<String>.broadcast();

  // Subscription preferences
  String? _robotId;
  bool _includeSensors = false;
  bool _includeSystem = false;

  /// Stream of connection state changes.
  Stream<WebSocketConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  /// Current connection state.
  WebSocketConnectionState get connectionState => _connectionState;

  /// Stream of telemetry updates.
  Stream<TelemetryData> get telemetryStream => _telemetryController.stream;

  /// Stream of error messages.
  Stream<String> get errorStream => _errorController.stream;

  /// Whether currently connected.
  bool get isConnected =>
      _connectionState == WebSocketConnectionState.connected;

  /// Connect to the telemetry WebSocket.
  ///
  /// Parameters:
  /// - [robotId]: Filter to specific robot (optional)
  /// - [includeSensors]: Include sensor data in updates
  /// - [includeSystem]: Include system health data
  Future<void> connect({
    String? robotId,
    bool includeSensors = false,
    bool includeSystem = false,
  }) async {
    if (_connectionState == WebSocketConnectionState.connected ||
        _connectionState == WebSocketConnectionState.connecting) {
      return;
    }

    _robotId = robotId;
    _includeSensors = includeSensors;
    _includeSystem = includeSystem;

    await _doConnect();
  }

  Future<void> _doConnect() async {
    _setConnectionState(WebSocketConnectionState.connecting);
    _cancelReconnectTimer();

    try {
      // Build WebSocket URL with query params
      final queryParams = <String, String>{};
      if (_robotId != null) queryParams['robot_id'] = _robotId!;
      if (_includeSensors) queryParams['include_sensors'] = 'true';
      if (_includeSystem) queryParams['include_system'] = 'true';

      final uri = Uri.parse(
        '$_baseUrl/telemetry',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      developer.log(
        'Connecting to WebSocket: $uri',
        name: 'TelemetryWebSocketService',
      );

      _channel = WebSocketChannel.connect(uri);

      // Wait for connection
      await _channel!.ready;

      _setConnectionState(WebSocketConnectionState.connected);
      _reconnectAttempts = 0;

      developer.log('WebSocket connected', name: 'TelemetryWebSocketService');

      // Listen to messages
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      developer.log(
        'WebSocket connection failed: $e',
        name: 'TelemetryWebSocketService',
        error: e,
      );
      _errorController.add('Connection failed: $e');
      _handleDisconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;

      // Check for error responses
      if (data['type'] == 'error') {
        _errorController.add(data['message'] as String? ?? 'Unknown error');
        return;
      }

      // Check for command responses
      if (data['type'] == 'pong' ||
          data['type'] == 'subscribed' ||
          data['type'] == 'unsubscribed') {
        developer.log(
          'WebSocket response: ${data['type']}',
          name: 'TelemetryWebSocketService',
        );
        return;
      }

      // Parse telemetry data
      final telemetry = TelemetryData.fromJson(data);
      _telemetryController.add(telemetry);
    } catch (e) {
      developer.log(
        'Failed to parse WebSocket message: $e',
        name: 'TelemetryWebSocketService',
        error: e,
      );
    }
  }

  void _onError(Object error) {
    developer.log(
      'WebSocket error: $error',
      name: 'TelemetryWebSocketService',
      error: error,
    );
    _errorController.add('WebSocket error: $error');
  }

  void _onDone() {
    developer.log('WebSocket closed', name: 'TelemetryWebSocketService');
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    if (_connectionState == WebSocketConnectionState.disconnected) {
      return;
    }

    if (autoReconnect && _reconnectAttempts < maxReconnectAttempts) {
      _setConnectionState(WebSocketConnectionState.reconnecting);
      _scheduleReconnect();
    } else {
      _setConnectionState(WebSocketConnectionState.disconnected);
      if (_reconnectAttempts >= maxReconnectAttempts) {
        _errorController.add('Max reconnection attempts reached');
      }
    }
  }

  void _scheduleReconnect() {
    _cancelReconnectTimer();

    // Exponential backoff with jitter
    final backoffMs =
        initialReconnectDelay.inMilliseconds *
        (1 << _reconnectAttempts.clamp(0, 10));
    final delay = Duration(
      milliseconds: backoffMs.clamp(
        initialReconnectDelay.inMilliseconds,
        maxReconnectDelay.inMilliseconds,
      ),
    );

    developer.log(
      'Scheduling reconnect in ${delay.inSeconds}s (attempt ${_reconnectAttempts + 1})',
      name: 'TelemetryWebSocketService',
    );

    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      _doConnect();
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _setConnectionState(WebSocketConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      _connectionStateController.add(state);
    }
  }

  /// Update subscription preferences.
  Future<void> updateSubscription({
    String? robotId,
    bool? includeSensors,
    bool? includeSystem,
  }) async {
    if (!isConnected) return;

    final payload = <String, dynamic>{};
    if (robotId != null) payload['robot_id'] = robotId;
    if (includeSensors != null) payload['include_sensors'] = includeSensors;
    if (includeSystem != null) payload['include_system'] = includeSystem;

    _sendCommand('subscribe', payload);

    // Update local state
    if (robotId != null) _robotId = robotId;
    if (includeSensors != null) _includeSensors = includeSensors;
    if (includeSystem != null) _includeSystem = includeSystem;
  }

  /// Send a ping to keep connection alive.
  void ping() {
    _sendCommand('ping', null);
  }

  void _sendCommand(String type, Map<String, dynamic>? payload) {
    if (_channel == null) return;

    try {
      _channel!.sink.add(
        jsonEncode({'type': type, if (payload != null) 'payload': payload}),
      );
    } catch (e) {
      developer.log(
        'Failed to send WebSocket command: $e',
        name: 'TelemetryWebSocketService',
        error: e,
      );
    }
  }

  /// Disconnect from WebSocket.
  Future<void> disconnect() async {
    _cancelReconnectTimer();
    _reconnectAttempts = maxReconnectAttempts; // Prevent auto-reconnect

    await _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    _setConnectionState(WebSocketConnectionState.disconnected);
  }

  /// Dispose all resources.
  Future<void> dispose() async {
    await disconnect();
    await _connectionStateController.close();
    await _telemetryController.close();
    await _errorController.close();
  }
}
