class ApiEndpoints {
  const ApiEndpoints._();

  static final String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.100:8000/api/v1',
  );

  static final String robotSocketUrl = const String.fromEnvironment(
    'ROBOT_STATUS_WS_URL',
    defaultValue: 'ws://192.168.1.100:8000/ws/robot-status',
  );

  /// WebSocket base URL for telemetry streaming.
  static final String wsBaseUrl = const String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://192.168.1.100:8000/api/v1/ws',
  );

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';
  static const String robotMotion = '/robot/control/move';
  static const String robotStop = '/robot/control/stop';
  static const String robotStatus = '/robot/status';
  static const String robotDiscovery = '/robot/discovery';

  // Voice endpoints
  static const String voiceCommand = '/voice/command';
  static const String voiceFeedback = '/voice/command/feedback';
  static const String voiceCapabilities = '/voice/capabilities';

  // Notification endpoints
  static const String notifications = '/notifications';
  static const String notificationUnreadCount = '/notifications/unread-count';
  static const String notificationStats = '/notifications/stats';
  static const String notificationReadAll = '/notifications/read-all';
  static const String notificationPreferences = '/notifications/preferences';
  static const String notificationPushToken = '/notifications/push-token';
  static const String notificationTest = '/notifications/test';

  // Camera endpoints
  static const String cameraStreamStart = '/camera/stream/start';
  static const String cameraStreamStop = '/camera/stream';
  static const String cameraSnapshot = '/camera/snapshot';
  static const String cameraSettings = '/camera';

  static String resolve(String path) => '$baseUrl$path';

  static Uri robotStatusSocketUri() => Uri.parse(robotSocketUrl);

  static Uri telemetrySocketUri({String? robotId}) {
    final base = Uri.parse('$wsBaseUrl/telemetry');
    if (robotId != null) {
      return base.replace(queryParameters: {'robot_id': robotId});
    }
    return base;
  }

  /// WebSocket URI for real-time notifications.
  static Uri notificationSocketUri(String userId) {
    return Uri.parse('$wsBaseUrl/../notifications/ws/$userId');
  }

  /// MJPEG stream URL for camera.
  static String mjpegStreamUrl(String cameraId, String sessionId) {
    return '$baseUrl/camera/$cameraId/stream/mjpeg?session=$sessionId';
  }

  /// WebSocket URI for camera frames.
  static Uri cameraSocketUri(String cameraId) {
    return Uri.parse('$wsBaseUrl/../camera/$cameraId/ws');
  }
}
