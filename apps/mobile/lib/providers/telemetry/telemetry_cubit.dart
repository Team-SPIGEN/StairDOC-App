/// Cubit for managing real-time telemetry state.
///
/// Handles:
/// - WebSocket connection lifecycle
/// - Telemetry stream subscription
/// - Connection state updates
/// - Error handling
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';

import '../../services/telemetry_websocket_service.dart';
import 'telemetry_state.dart';

export 'telemetry_state.dart';

/// Cubit for real-time telemetry management.
///
/// Usage:
/// ```dart
/// BlocProvider(
///   create: (context) => TelemetryCubit(
///     webSocketService: TelemetryWebSocketService(),
///   )..connect(),
///   child: MyWidget(),
/// )
/// ```
class TelemetryCubit extends Cubit<TelemetryState> {
  TelemetryCubit({required TelemetryWebSocketService webSocketService})
    : _wsService = webSocketService,
      super(const TelemetryState());

  final TelemetryWebSocketService _wsService;

  StreamSubscription? _connectionSub;
  StreamSubscription? _telemetrySub;
  StreamSubscription? _errorSub;

  /// Connect to telemetry WebSocket.
  ///
  /// Parameters:
  /// - [robotId]: Filter to specific robot
  /// - [includeSensors]: Include sensor data
  /// - [includeSystem]: Include system health
  Future<void> connect({
    String? robotId,
    bool includeSensors = true,
    bool includeSystem = true,
  }) async {
    // Subscribe to streams before connecting
    _setupSubscriptions();

    try {
      await _wsService.connect(
        robotId: robotId,
        includeSensors: includeSensors,
        includeSystem: includeSystem,
      );
    } catch (e) {
      developer.log(
        'Failed to connect to telemetry WebSocket',
        name: 'TelemetryCubit',
        error: e,
      );
      emit(
        state.copyWith(
          connectionState: WebSocketConnectionState.disconnected,
          errorMessage: 'Failed to connect: $e',
          errorTimestamp: DateTime.now(),
        ),
      );
    }
  }

  void _setupSubscriptions() {
    // Cancel existing subscriptions
    _connectionSub?.cancel();
    _telemetrySub?.cancel();
    _errorSub?.cancel();

    // Connection state
    _connectionSub = _wsService.connectionStateStream.listen((connState) {
      emit(
        state.copyWith(
          connectionState: connState,
          clearError: connState == WebSocketConnectionState.connected,
        ),
      );
    });

    // Telemetry updates
    _telemetrySub = _wsService.telemetryStream.listen((telemetry) {
      emit(state.copyWith(telemetry: telemetry, lastUpdated: DateTime.now()));
    });

    // Errors
    _errorSub = _wsService.errorStream.listen((error) {
      emit(state.copyWith(errorMessage: error, errorTimestamp: DateTime.now()));
    });
  }

  /// Disconnect from WebSocket.
  Future<void> disconnect() async {
    await _wsService.disconnect();
    emit(
      state.copyWith(
        connectionState: WebSocketConnectionState.disconnected,
        clearTelemetry: true,
      ),
    );
  }

  /// Reconnect to WebSocket.
  Future<void> reconnect({
    String? robotId,
    bool includeSensors = true,
    bool includeSystem = true,
  }) async {
    await disconnect();
    await connect(
      robotId: robotId,
      includeSensors: includeSensors,
      includeSystem: includeSystem,
    );
  }

  /// Update subscription preferences.
  Future<void> updateSubscription({
    String? robotId,
    bool? includeSensors,
    bool? includeSystem,
  }) async {
    await _wsService.updateSubscription(
      robotId: robotId,
      includeSensors: includeSensors,
      includeSystem: includeSystem,
    );
  }

  /// Clear error state.
  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  @override
  Future<void> close() async {
    await _connectionSub?.cancel();
    await _telemetrySub?.cancel();
    await _errorSub?.cancel();
    await _wsService.dispose();
    return super.close();
  }
}
