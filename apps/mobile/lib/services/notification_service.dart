/// Notification service for real-time alerts.
///
/// Handles WebSocket connection for real-time notifications and REST API calls.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/notification.dart';
import '../utils/api_endpoints.dart';

/// Service for managing notifications via WebSocket and REST API.
class NotificationService {
  NotificationService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  String? _currentUserId;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _pingInterval = Duration(seconds: 30);
  static const Duration _initialReconnectDelay = Duration(seconds: 1);

  /// Stream controller for incoming notifications.
  final _notificationController = StreamController<AppNotification>.broadcast();

  /// Stream controller for connection state changes.
  final _connectionStateController = StreamController<bool>.broadcast();

  /// Stream of incoming notifications.
  Stream<AppNotification> get notificationStream =>
      _notificationController.stream;

  /// Stream of connection state changes.
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  /// Whether the WebSocket is currently connected.
  bool get isConnected => _isConnected;

  // ===========================================================================
  // WebSocket Connection Management
  // ===========================================================================

  /// Connect to the notification WebSocket.
  Future<void> connect(String userId) async {
    if (_isConnected && _currentUserId == userId) {
      return;
    }

    // Disconnect existing connection if different user
    if (_currentUserId != null && _currentUserId != userId) {
      await disconnect();
    }

    _currentUserId = userId;
    await _establishConnection();
  }

  Future<void> _establishConnection() async {
    if (_currentUserId == null) return;

    try {
      final uri = ApiEndpoints.notificationSocketUri(_currentUserId!);
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionStateController.add(true);

      // Start ping timer to keep connection alive
      _startPingTimer();
    } catch (e) {
      _handleError(e);
    }
  }

  /// Disconnect from the notification WebSocket.
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();

    _channel = null;
    _subscription = null;
    _currentUserId = null;
    _isConnected = false;
    _connectionStateController.add(false);
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'notification') {
        final event = NotificationEvent.fromJson(data);
        _notificationController.add(event.notification);
      } else if (type == 'pong') {
        // Pong received, connection is healthy
      } else if (type == 'ack') {
        // Acknowledgment received for a command
      }
    } catch (e) {
      // Ignore malformed messages
    }
  }

  void _handleError(dynamic error) {
    _isConnected = false;
    _connectionStateController.add(false);
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    _isConnected = false;
    _connectionStateController.add(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    _reconnectTimer?.cancel();

    // Exponential backoff
    final delay = _initialReconnectDelay * (1 << _reconnectAttempts);
    _reconnectAttempts++;

    _reconnectTimer = Timer(delay, () {
      if (_currentUserId != null && !_isConnected) {
        _establishConnection();
      }
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_isConnected && _channel != null) {
        _channel!.sink.add(jsonEncode({'command': 'ping'}));
      }
    });
  }

  // ===========================================================================
  // WebSocket Commands
  // ===========================================================================

  /// Mark a notification as read via WebSocket.
  void markAsReadWs(String notificationId) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(
      jsonEncode({'command': 'mark_read', 'notification_id': notificationId}),
    );
  }

  /// Mark all notifications as read via WebSocket.
  void markAllAsReadWs() {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(jsonEncode({'command': 'mark_all_read'}));
  }

  /// Dismiss a notification via WebSocket.
  void dismissWs(String notificationId) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(
      jsonEncode({'command': 'dismiss', 'notification_id': notificationId}),
    );
  }

  // ===========================================================================
  // REST API Methods
  // ===========================================================================

  /// Fetch notifications from the API.
  Future<NotificationListResponse> fetchNotifications({
    required String userId,
    int page = 1,
    int pageSize = 20,
    bool unreadOnly = false,
    List<NotificationType>? types,
  }) async {
    final queryParams = {
      'user_id': userId,
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'unread_only': unreadOnly.toString(),
    };

    if (types != null && types.isNotEmpty) {
      queryParams['types'] = types.map((t) => t.value).join(',');
    }

    final uri = Uri.parse(
      ApiEndpoints.resolve(ApiEndpoints.notifications),
    ).replace(queryParameters: queryParams);

    final response = await _httpClient.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return NotificationListResponse.fromJson(data);
    }

    throw Exception('Failed to fetch notifications: ${response.statusCode}');
  }

  /// Get unread notification count.
  Future<int> fetchUnreadCount(String userId) async {
    final uri = Uri.parse(
      ApiEndpoints.resolve(ApiEndpoints.notificationUnreadCount),
    ).replace(queryParameters: {'user_id': userId});

    final response = await _httpClient.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['unread_count'] as int;
    }

    throw Exception('Failed to fetch unread count: ${response.statusCode}');
  }

  /// Get notification statistics.
  Future<NotificationStats> fetchStats(String userId) async {
    final uri = Uri.parse(
      ApiEndpoints.resolve(ApiEndpoints.notificationStats),
    ).replace(queryParameters: {'user_id': userId});

    final response = await _httpClient.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return NotificationStats.fromJson(data);
    }

    throw Exception('Failed to fetch stats: ${response.statusCode}');
  }

  /// Mark a notification as read via REST API.
  Future<AppNotification> markAsRead(
    String notificationId,
    String userId,
  ) async {
    final uri = Uri.parse(
      ApiEndpoints.resolve(
        '${ApiEndpoints.notifications}/$notificationId/read',
      ),
    ).replace(queryParameters: {'user_id': userId});

    final response = await _httpClient.post(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AppNotification.fromJson(data);
    }

    throw Exception('Failed to mark as read: ${response.statusCode}');
  }

  /// Mark all notifications as read via REST API.
  Future<int> markAllAsRead(String userId) async {
    final uri = Uri.parse(
      ApiEndpoints.resolve(ApiEndpoints.notificationReadAll),
    ).replace(queryParameters: {'user_id': userId});

    final response = await _httpClient.post(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['marked_count'] as int;
    }

    throw Exception('Failed to mark all as read: ${response.statusCode}');
  }

  /// Dismiss a notification via REST API.
  Future<AppNotification> dismiss(String notificationId, String userId) async {
    final uri = Uri.parse(
      ApiEndpoints.resolve(
        '${ApiEndpoints.notifications}/$notificationId/dismiss',
      ),
    ).replace(queryParameters: {'user_id': userId});

    final response = await _httpClient.post(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AppNotification.fromJson(data);
    }

    throw Exception('Failed to dismiss: ${response.statusCode}');
  }

  // ===========================================================================
  // Preferences
  // ===========================================================================

  /// Fetch notification preferences.
  Future<NotificationPreferences> fetchPreferences(String userId) async {
    final uri = Uri.parse(
      ApiEndpoints.resolve('${ApiEndpoints.notificationPreferences}/$userId'),
    );

    final response = await _httpClient.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return NotificationPreferences.fromJson(data);
    }

    throw Exception('Failed to fetch preferences: ${response.statusCode}');
  }

  /// Update notification preferences.
  Future<NotificationPreferences> updatePreferences(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    final uri = Uri.parse(
      ApiEndpoints.resolve('${ApiEndpoints.notificationPreferences}/$userId'),
    );

    final response = await _httpClient.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updates),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return NotificationPreferences.fromJson(data);
    }

    throw Exception('Failed to update preferences: ${response.statusCode}');
  }

  // ===========================================================================
  // Push Token
  // ===========================================================================

  /// Register a push notification token.
  Future<void> registerPushToken({
    required String userId,
    required String token,
    required String platform,
    String? deviceId,
  }) async {
    final uri = Uri.parse(
      ApiEndpoints.resolve(ApiEndpoints.notificationPushToken),
    );

    final response = await _httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'token': token,
        'platform': platform,
        'device_id': deviceId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to register push token: ${response.statusCode}');
    }
  }

  /// Unregister a push notification token.
  Future<void> unregisterPushToken(String userId, String token) async {
    final uri = Uri.parse(
      ApiEndpoints.resolve(ApiEndpoints.notificationPushToken),
    ).replace(queryParameters: {'user_id': userId, 'token': token});

    final response = await _httpClient.delete(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to unregister push token: ${response.statusCode}',
      );
    }
  }

  // ===========================================================================
  // Test
  // ===========================================================================

  /// Send a test notification (for development/testing).
  Future<AppNotification> sendTestNotification({
    required String userId,
    String title = 'Test Notification',
    String body = 'This is a test notification.',
    NotificationType type = NotificationType.systemInfo,
  }) async {
    final uri = Uri.parse(ApiEndpoints.resolve(ApiEndpoints.notificationTest));

    final response = await _httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type.value,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AppNotification.fromJson(data);
    }

    throw Exception('Failed to send test notification: ${response.statusCode}');
  }

  /// Dispose resources.
  void dispose() {
    disconnect();
    _notificationController.close();
    _connectionStateController.close();
  }
}
