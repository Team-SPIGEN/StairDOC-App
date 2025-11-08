class AppConfig {
  const AppConfig._();

  /// Enables mock authentication flows for development without a backend.
  static const bool enableMockAuth = bool.fromEnvironment(
    'ENABLE_MOCK_AUTH',
    defaultValue: false,
  );

  /// Optional artificial delay to mimic network latency during mock auth.
  static const int mockLatencyMs = int.fromEnvironment(
    'MOCK_AUTH_LATENCY_MS',
    defaultValue: 450,
  );

  static const String mockEmail = String.fromEnvironment(
    'MOCK_EMAIL',
    defaultValue: 'operator@stairdoc.dev',
  );

  static const String mockPassword = String.fromEnvironment(
    'MOCK_PASSWORD',
    defaultValue: 'Password123!',
  );

  static const String mockName = String.fromEnvironment(
    'MOCK_NAME',
    defaultValue: 'Dev Operator',
  );

  static const String mockRole = String.fromEnvironment(
    'MOCK_ROLE',
    defaultValue: 'operator',
  );

  static Map<String, dynamic> get mockUserJson => {
    'id': 'dev-operator',
    'name': mockName,
    'email': mockEmail,
    'role': mockRole,
  };

  static String buildMockToken() =>
      'mock-token-${DateTime.now().millisecondsSinceEpoch}';
}
