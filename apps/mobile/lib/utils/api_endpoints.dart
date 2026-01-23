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

  static String resolve(String path) => '$baseUrl$path';

  static Uri robotStatusSocketUri() => Uri.parse(robotSocketUrl);

  static Uri telemetrySocketUri({String? robotId}) {
    final base = Uri.parse('$wsBaseUrl/telemetry');
    if (robotId != null) {
      return base.replace(queryParameters: {'robot_id': robotId});
    }
    return base;
  }
}
