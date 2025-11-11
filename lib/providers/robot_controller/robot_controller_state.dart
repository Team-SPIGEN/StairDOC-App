import 'package:equatable/equatable.dart';
import 'package:stairdoc/models/robot_endpoint.dart';
import 'package:stairdoc/models/robot_motion_command.dart';

enum RobotConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class RobotControllerState extends Equatable {
  const RobotControllerState({
    required this.connectionStatus,
    required this.isSending,
    required this.lastCommand,
    required this.lastUpdated,
    required this.statusMessage,
    required this.statusTimestamp,
    required this.errorMessage,
    required this.errorTimestamp,
    required this.isScanning,
    required this.availableRobots,
    required this.selectedRobot,
    required this.discoveryError,
    required this.discoveryTimestamp,
    this.batteryPercentage,
    this.floor,
    this.linearVelocity,
  });

  const RobotControllerState.initial()
    : connectionStatus = RobotConnectionStatus.disconnected,
      isSending = false,
      lastCommand = null,
      lastUpdated = null,
      statusMessage = null,
      statusTimestamp = null,
      errorMessage = null,
      errorTimestamp = null,
      isScanning = false,
      availableRobots = const [],
      selectedRobot = null,
      discoveryError = null,
      discoveryTimestamp = null,
      batteryPercentage = null,
      floor = null,
      linearVelocity = null;

  final RobotConnectionStatus connectionStatus;
  final bool isSending;
  final RobotMotionCommand? lastCommand;
  final DateTime? lastUpdated;
  final String? statusMessage;
  final DateTime? statusTimestamp;
  final String? errorMessage;
  final DateTime? errorTimestamp;
  final bool isScanning;
  final List<RobotEndpoint> availableRobots;
  final RobotEndpoint? selectedRobot;
  final String? discoveryError;
  final DateTime? discoveryTimestamp;
  final double? batteryPercentage;
  final int? floor;
  final double? linearVelocity;

  RobotControllerState copyWith({
    RobotConnectionStatus? connectionStatus,
    bool? isSending,
    RobotMotionCommand? lastCommand,
    DateTime? lastUpdated,
    String? statusMessage,
    DateTime? statusTimestamp,
    String? errorMessage,
    DateTime? errorTimestamp,
    bool? isScanning,
    List<RobotEndpoint>? availableRobots,
    RobotEndpoint? selectedRobot,
    String? discoveryError,
    DateTime? discoveryTimestamp,
    double? batteryPercentage,
    int? floor,
    double? linearVelocity,
    bool clearError = false,
    bool clearDiscoveryError = false,
    bool clearSelectedRobot = false,
  }) {
    return RobotControllerState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isSending: isSending ?? this.isSending,
      lastCommand: lastCommand ?? this.lastCommand,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      statusMessage: statusMessage ?? this.statusMessage,
      statusTimestamp: statusTimestamp ?? this.statusTimestamp,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorTimestamp: clearError
          ? null
          : (errorTimestamp ?? this.errorTimestamp),
      isScanning: isScanning ?? this.isScanning,
      availableRobots: availableRobots ?? this.availableRobots,
      selectedRobot: clearSelectedRobot
          ? null
          : (selectedRobot ?? this.selectedRobot),
      discoveryError: clearDiscoveryError
          ? null
          : (discoveryError ?? this.discoveryError),
      discoveryTimestamp: discoveryTimestamp ?? this.discoveryTimestamp,
      batteryPercentage: batteryPercentage ?? this.batteryPercentage,
      floor: floor ?? this.floor,
      linearVelocity: linearVelocity ?? this.linearVelocity,
    );
  }

  @override
  List<Object?> get props => [
    connectionStatus,
    isSending,
    lastCommand,
    lastUpdated,
    statusMessage,
    statusTimestamp,
    errorMessage,
    errorTimestamp,
    isScanning,
    availableRobots,
    selectedRobot,
    discoveryError,
    discoveryTimestamp,
    batteryPercentage,
    floor,
    linearVelocity,
  ];
}
