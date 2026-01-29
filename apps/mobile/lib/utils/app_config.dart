/// Environment configuration for the StairDOC mobile app.
///
/// Use --dart-define flags when building:
///
/// Development:
///   flutter run --dart-define=ENVIRONMENT=development
///
/// Production:
///   flutter build apk --release \
///     --dart-define=ENVIRONMENT=production \
///     --dart-define=API_BASE_URL=https://api.stairdoc.com/api/v1
library;

/// Application environment enumeration.
enum Environment {
  development,
  staging,
  production;

  static Environment fromString(String value) {
    return Environment.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => Environment.development,
    );
  }
}

class AppConfig {
  const AppConfig._();

  // ===========================================================================
  // Environment Detection
  // ===========================================================================

  /// Current environment (set via --dart-define=ENVIRONMENT=xxx)
  static const String _envString = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static final Environment environment = Environment.fromString(_envString);

  /// Whether the app is running in production mode.
  static bool get isProduction => environment == Environment.production;

  /// Whether the app is running in development mode.
  static bool get isDevelopment => environment == Environment.development;

  /// Whether debug features should be enabled.
  static bool get enableDebugFeatures => !isProduction;

  /// Whether to log API requests/responses.
  static bool get enableApiLogging => !isProduction;

  /// Whether to show developer tools.
  static bool get showDevTools => isDevelopment;

  // ===========================================================================
  // Timeouts & Performance
  // ===========================================================================

  /// API request timeout duration.
  static Duration get apiTimeout =>
      isProduction ? const Duration(seconds: 30) : const Duration(seconds: 60);

  /// WebSocket reconnection delay.
  static Duration get wsReconnectDelay =>
      isProduction ? const Duration(seconds: 5) : const Duration(seconds: 2);

  /// Maximum retry attempts for API calls.
  static int get maxRetryAttempts => isProduction ? 3 : 5;

  /// Cache duration for robot status.
  static Duration get robotStatusCacheDuration => const Duration(seconds: 5);

  /// Cache duration for delivery jobs list.
  static Duration get deliveryJobsCacheDuration => const Duration(seconds: 30);

  /// Telemetry update interval.
  static Duration get telemetryUpdateInterval =>
      const Duration(milliseconds: 500);

  // ===========================================================================
  // Version Info
  // ===========================================================================

  /// App version (injected at build time).
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  /// Build number (injected at build time).
  static const String buildNumber = String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: '1',
  );

  /// Full version string.
  static String get fullVersion => '$appVersion+$buildNumber';

  // ===========================================================================
  // External Services
  // ===========================================================================

  /// Sentry DSN for error tracking (production only).
  static String? get sentryDsn {
    const dsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
    return dsn.isEmpty ? null : dsn;
  }

  /// Whether push notifications are enabled.
  static const bool enablePushNotifications = bool.fromEnvironment(
    'ENABLE_PUSH_NOTIFICATIONS',
    defaultValue: false,
  );

  // ===========================================================================
  // Mock Authentication (Development Only)
  // ===========================================================================

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
