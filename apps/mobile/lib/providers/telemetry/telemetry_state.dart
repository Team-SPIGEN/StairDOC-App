/// Telemetry state for BLoC state management.
///
/// Represents the state of real-time telemetry including:
/// - Connection status
/// - Current telemetry data
/// - Error states
library;

import 'package:equatable/equatable.dart';

import '../../models/telemetry.dart';
import '../../services/telemetry_websocket_service.dart';

/// State for the [TelemetryCubit].
class TelemetryState extends Equatable {
  const TelemetryState({
    this.connectionState = WebSocketConnectionState.disconnected,
    this.telemetry,
    this.lastUpdated,
    this.errorMessage,
    this.errorTimestamp,
  });

  /// WebSocket connection state.
  final WebSocketConnectionState connectionState;

  /// Current telemetry data (null if not yet received).
  final TelemetryData? telemetry;

  /// Timestamp of last telemetry update.
  final DateTime? lastUpdated;

  /// Error message if any.
  final String? errorMessage;

  /// Timestamp of last error.
  final DateTime? errorTimestamp;

  /// Whether connected to WebSocket.
  bool get isConnected => connectionState == WebSocketConnectionState.connected;

  /// Whether currently reconnecting.
  bool get isReconnecting =>
      connectionState == WebSocketConnectionState.reconnecting;

  /// Whether connecting.
  bool get isConnecting =>
      connectionState == WebSocketConnectionState.connecting;

  /// Whether has telemetry data.
  bool get hasTelemetry => telemetry != null;

  /// Shortcut to battery percentage.
  int? get batteryPercentage => telemetry?.battery.percentage;

  /// Shortcut to current floor.
  int? get currentFloor => telemetry?.location.floor;

  /// Shortcut to robot state.
  RobotState? get robotState => telemetry?.state;

  /// Shortcut to container state.
  ContainerState? get containerState => telemetry?.containerState;

  /// Create a copy with updated fields.
  TelemetryState copyWith({
    WebSocketConnectionState? connectionState,
    TelemetryData? telemetry,
    DateTime? lastUpdated,
    String? errorMessage,
    DateTime? errorTimestamp,
    bool clearError = false,
    bool clearTelemetry = false,
  }) {
    return TelemetryState(
      connectionState: connectionState ?? this.connectionState,
      telemetry: clearTelemetry ? null : (telemetry ?? this.telemetry),
      lastUpdated: lastUpdated ?? this.lastUpdated,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorTimestamp: clearError
          ? null
          : (errorTimestamp ?? this.errorTimestamp),
    );
  }

  @override
  List<Object?> get props => [
    connectionState,
    telemetry,
    lastUpdated,
    errorMessage,
    errorTimestamp,
  ];
}
