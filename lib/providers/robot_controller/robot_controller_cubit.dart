import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:stairdoc/models/robot_motion_command.dart';

import '../../models/robot_endpoint.dart';
import '../../services/robot_api_service.dart';
import '../../services/robot_discovery_service.dart';
import 'robot_controller_state.dart';

class RobotControllerCubit extends Cubit<RobotControllerState> {
  RobotControllerCubit({
    required RobotApiService robotApiService,
    required RobotDiscoveryService discoveryService,
  }) : _robotApiService = robotApiService,
       _discoveryService = discoveryService,
       super(const RobotControllerState.initial());

  final RobotApiService _robotApiService;
  final RobotDiscoveryService _discoveryService;

  RobotEndpoint? _selectedEndpoint;
  WebSocketChannel? _statusChannel;
  StreamSubscription<dynamic>? _statusSubscription;
  Timer? _reconnectTimer;

  void initialize() {
    unawaited(discoverRobots(autoConnectOnSingle: true));
  }

  Future<void> discoverRobots({bool autoConnectOnSingle = false}) async {
    if (state.isScanning) return;

    emit(state.copyWith(isScanning: true, clearDiscoveryError: true));

    try {
      final results = await _discoveryService.discoverRobots();
      RobotEndpoint? selected = _selectedEndpoint ?? state.selectedRobot;
      selected = _matchEndpoint(results, selected);

      if (selected == null && results.length == 1 && autoConnectOnSingle) {
        selected = results.first;
      }

      _selectedEndpoint = selected;
      _robotApiService.updateEndpoint(selected);

      final shouldUpdateStatus =
          state.connectionStatus != RobotConnectionStatus.connected;

      emit(
        state.copyWith(
          isScanning: false,
          availableRobots: results,
          selectedRobot: selected,
          discoveryTimestamp: DateTime.now(),
          clearSelectedRobot: selected == null,
          statusMessage: shouldUpdateStatus && results.isEmpty
              ? 'No robots discovered. Ensure the robot and your device are on the same network.'
              : state.statusMessage,
          statusTimestamp: shouldUpdateStatus && results.isEmpty
              ? DateTime.now()
              : state.statusTimestamp,
        ),
      );

      if (autoConnectOnSingle && selected != null) {
        await connectToSelectedRobot();
      }
    } catch (error, stackTrace) {
      developer.log(
        'Robot discovery failed',
        name: 'RobotControllerCubit',
        error: error,
        stackTrace: stackTrace,
      );
      final friendlyMessage = _describeDiscoveryError(error);
      final timestamp = DateTime.now();
      emit(
        state.copyWith(
          isScanning: false,
          discoveryError: friendlyMessage,
          discoveryTimestamp: timestamp,
          statusMessage: state.selectedRobot == null
              ? friendlyMessage
              : state.statusMessage,
          statusTimestamp: state.selectedRobot == null
              ? timestamp
              : state.statusTimestamp,
        ),
      );
    }
  }

  void selectRobot(RobotEndpoint endpoint) {
    if (_selectedEndpoint?.id == endpoint.id) return;

    _disconnectStatusStream();
    _selectedEndpoint = endpoint;
    _robotApiService.updateEndpoint(endpoint);

    emit(
      state.copyWith(
        selectedRobot: endpoint,
        connectionStatus: RobotConnectionStatus.disconnected,
        statusMessage: 'Ready to connect to ${endpoint.name}',
        statusTimestamp: DateTime.now(),
        clearError: true,
      ),
    );
  }

  Future<void> connectToSelectedRobot() async {
    final endpoint = _selectedEndpoint;
    if (endpoint == null) {
      emit(
        state.copyWith(
          errorMessage: 'Select a robot before connecting.',
          errorTimestamp: DateTime.now(),
        ),
      );
      return;
    }

    _disconnectStatusStream();
    emit(
      state.copyWith(
        connectionStatus: RobotConnectionStatus.connecting,
        statusMessage: 'Connecting to ${endpoint.name}…',
        statusTimestamp: DateTime.now(),
        clearError: true,
      ),
    );
    _connectToStatusStream();
  }

  void disconnect() {
    _disconnectStatusStream();
    emit(
      state.copyWith(
        connectionStatus: RobotConnectionStatus.disconnected,
        statusMessage: 'Disconnected',
        statusTimestamp: DateTime.now(),
      ),
    );
  }

  Future<void> sendCommand(RobotMotionCommand command) async {
    if (state.isSending) return;
    if (_selectedEndpoint == null) {
      emit(
        state.copyWith(
          errorMessage: 'Select a robot before sending commands.',
          errorTimestamp: DateTime.now(),
        ),
      );
      return;
    }

    emit(state.copyWith(isSending: true, clearError: true));

    try {
      await _robotApiService.sendMovementCommand(command);
      final now = DateTime.now();
      emit(
        state.copyWith(
          isSending: false,
          lastCommand: command,
          lastUpdated: now,
          statusMessage: 'Command "${command.label}" sent',
          statusTimestamp: now,
        ),
      );
    } on RobotControlException catch (error) {
      emit(
        state.copyWith(
          isSending: false,
          errorMessage: error.message,
          errorTimestamp: DateTime.now(),
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isSending: false,
          errorMessage: 'Failed to send command. Please try again.',
          errorTimestamp: DateTime.now(),
        ),
      );
    }
  }

  void refreshStatus() {
    if (_selectedEndpoint == null) {
      emit(
        state.copyWith(
          statusMessage: 'Scanning for robots…',
          statusTimestamp: DateTime.now(),
        ),
      );
      unawaited(discoverRobots(autoConnectOnSingle: true));
      return;
    }

    _disconnectStatusStream();
    emit(
      state.copyWith(
        connectionStatus: RobotConnectionStatus.reconnecting,
        statusMessage: 'Reconnecting…',
        statusTimestamp: DateTime.now(),
        clearError: true,
      ),
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      const Duration(milliseconds: 800),
      _connectToStatusStream,
    );
  }

  void _connectToStatusStream() {
    final endpoint = _selectedEndpoint;
    if (endpoint == null) {
      emit(
        state.copyWith(
          connectionStatus: RobotConnectionStatus.disconnected,
          statusMessage: 'Select a robot to connect.',
          statusTimestamp: DateTime.now(),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        connectionStatus: RobotConnectionStatus.connecting,
        selectedRobot: endpoint,
      ),
    );

    try {
      final channel = _robotApiService.openStatusChannel();
      _statusChannel = channel;
      _statusSubscription = channel.stream.listen(
        _handleStatusPayload,
        onError: (error) {
          emit(
            state.copyWith(
              connectionStatus: RobotConnectionStatus.error,
              errorMessage: 'Connection error: $error',
              errorTimestamp: DateTime.now(),
            ),
          );
          _scheduleReconnect();
        },
        onDone: () {
          emit(
            state.copyWith(
              connectionStatus: RobotConnectionStatus.disconnected,
              statusMessage: 'Connection closed',
              statusTimestamp: DateTime.now(),
            ),
          );
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
      emit(
        state.copyWith(
          connectionStatus: RobotConnectionStatus.connected,
          statusMessage:
              'Connected to ${endpoint.name}. Listening for updates…',
          statusTimestamp: DateTime.now(),
          clearError: true,
        ),
      );
    } on RobotControlException catch (error) {
      emit(
        state.copyWith(
          connectionStatus: RobotConnectionStatus.error,
          errorMessage: error.message,
          errorTimestamp: DateTime.now(),
        ),
      );
      _scheduleReconnect(const Duration(seconds: 2));
    } catch (error) {
      emit(
        state.copyWith(
          connectionStatus: RobotConnectionStatus.error,
          errorMessage: 'Unable to open status stream: $error',
          errorTimestamp: DateTime.now(),
        ),
      );
      _scheduleReconnect(const Duration(seconds: 2));
    }
  }

  void _handleStatusPayload(dynamic payload) {
    final now = DateTime.now();

    if (payload == null) {
      emit(
        state.copyWith(
          statusMessage: 'Empty status received',
          statusTimestamp: now,
        ),
      );
      return;
    }

    try {
      if (payload is String) {
        final decoded = jsonDecode(payload);
        _emitStatusFromDecoded(decoded, now, rawMessageFallback: payload);
      } else if (payload is List<int>) {
        final decodedString = utf8.decode(payload);
        final decoded = jsonDecode(decodedString);
        _emitStatusFromDecoded(decoded, now, rawMessageFallback: decodedString);
      } else if (payload is Map<String, dynamic>) {
        _emitStatusFromDecoded(payload, now);
      } else {
        emit(
          state.copyWith(
            statusMessage: payload.toString(),
            statusTimestamp: now,
          ),
        );
      }
    } catch (_) {
      emit(
        state.copyWith(statusMessage: payload.toString(), statusTimestamp: now),
      );
    }
  }

  void _emitStatusFromDecoded(
    dynamic decoded,
    DateTime timestamp, {
    String? rawMessageFallback,
  }) {
    String? message;
    double? battery;
    double? velocity;
    int? floor;

    if (decoded is Map<String, dynamic>) {
      message = decoded['message']?.toString() ?? decoded['status']?.toString();
      final batteryValue = decoded['battery'] ?? decoded['battery_level'];
      if (batteryValue is num) {
        battery = batteryValue.toDouble();
      } else if (batteryValue is String) {
        battery = double.tryParse(batteryValue);
      }

      final velocityValue = decoded['velocity'] ?? decoded['speed'];
      if (velocityValue is num) {
        velocity = velocityValue.toDouble();
      } else if (velocityValue is String) {
        velocity = double.tryParse(velocityValue);
      }

      final floorValue = decoded['floor'] ?? decoded['level'];
      if (floorValue is num) {
        floor = floorValue.toInt();
      } else if (floorValue is String) {
        floor = int.tryParse(floorValue);
      }
    }

    emit(
      state.copyWith(
        connectionStatus: RobotConnectionStatus.connected,
        statusMessage: message ?? rawMessageFallback ?? 'Heartbeat received',
        statusTimestamp: timestamp,
        batteryPercentage: battery ?? state.batteryPercentage,
        linearVelocity: velocity ?? state.linearVelocity,
        floor: floor ?? state.floor,
      ),
    );
  }

  void _scheduleReconnect([Duration delay = const Duration(seconds: 3)]) {
    _reconnectTimer?.cancel();
    if (_selectedEndpoint == null) {
      emit(
        state.copyWith(connectionStatus: RobotConnectionStatus.disconnected),
      );
      return;
    }
    emit(state.copyWith(connectionStatus: RobotConnectionStatus.reconnecting));
    _reconnectTimer = Timer(delay, _connectToStatusStream);
  }

  void _disconnectStatusStream() {
    _reconnectTimer?.cancel();
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _statusChannel?.sink.close();
    _statusChannel = null;
  }

  RobotEndpoint? _matchEndpoint(
    List<RobotEndpoint> endpoints,
    RobotEndpoint? reference,
  ) {
    if (reference == null) return null;
    for (final endpoint in endpoints) {
      final sameId = endpoint.id == reference.id;
      final sameAddress =
          endpoint.host == reference.host && endpoint.port == reference.port;
      if (sameId || sameAddress) {
        return endpoint;
      }
    }
    return null;
  }

  String _describeDiscoveryError(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          final timeout = error.requestOptions.connectTimeout;
          final durationLabel = timeout != null
              ? _formatDuration(timeout)
              : 'the expected window';
          return 'Discovery request timed out after $durationLabel. Ensure the robot or discovery API is reachable.';
        case DioExceptionType.connectionError:
          return 'Unable to reach the discovery service. Verify that your device and the robot are on the same network.';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final extracted = _extractMessage(error.response?.data);
          if (extracted != null && extracted.isNotEmpty) {
            return extracted;
          }
          if (statusCode != null) {
            return 'Discovery failed with HTTP $statusCode from the API.';
          }
          return 'Discovery failed with an unexpected server response.';
        case DioExceptionType.badCertificate:
          return 'Discovery failed due to an invalid certificate from the robot host.';
        case DioExceptionType.cancel:
          return 'Discovery request was cancelled before completing.';
        case DioExceptionType.unknown:
          break;
      }
    }

    return 'Unable to discover robots. Please try again after checking the network.';
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

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    if (seconds >= 60) {
      final minutes = duration.inMinutes;
      final remainingSeconds = seconds % 60;
      if (remainingSeconds == 0) {
        return '$minutes minute${minutes == 1 ? '' : 's'}';
      }
      return '$minutes minute${minutes == 1 ? '' : 's'} $remainingSeconds second${remainingSeconds == 1 ? '' : 's'}';
    }
    return '$seconds second${seconds == 1 ? '' : 's'}';
  }

  @override
  Future<void> close() {
    _disconnectStatusStream();
    return super.close();
  }
}
