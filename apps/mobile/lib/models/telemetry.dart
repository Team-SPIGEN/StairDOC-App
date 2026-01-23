/// Telemetry models for real-time robot data.
///
/// Maps to backend TelemetryData schema and provides
/// strongly-typed access to all robot telemetry fields.
library;

import 'package:equatable/equatable.dart';

/// Operational state of the robot.
enum RobotState {
  idle,
  moving,
  climbing,
  descending,
  delivering,
  returning,
  charging,
  error,
  maintenance;

  factory RobotState.fromString(String value) {
    return RobotState.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => RobotState.idle,
    );
  }

  String get displayName => switch (this) {
    RobotState.idle => 'Idle',
    RobotState.moving => 'Moving',
    RobotState.climbing => 'Climbing Stairs',
    RobotState.descending => 'Descending Stairs',
    RobotState.delivering => 'Delivering',
    RobotState.returning => 'Returning',
    RobotState.charging => 'Charging',
    RobotState.error => 'Error',
    RobotState.maintenance => 'Maintenance',
  };

  bool get isActive =>
      this == RobotState.moving ||
      this == RobotState.climbing ||
      this == RobotState.descending ||
      this == RobotState.delivering ||
      this == RobotState.returning;
}

/// State of the document container.
enum ContainerState {
  locked,
  unlocked,
  opening,
  closing;

  factory ContainerState.fromString(String value) {
    return ContainerState.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ContainerState.locked,
    );
  }

  bool get isLocked => this == ContainerState.locked;
  bool get isUnlocked => this == ContainerState.unlocked;
}

/// Network connectivity status.
enum ConnectivityStatus {
  online,
  offline,
  degraded;

  factory ConnectivityStatus.fromString(String value) {
    return ConnectivityStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ConnectivityStatus.offline,
    );
  }

  bool get isOnline => this == ConnectivityStatus.online;
}

/// Battery status information.
class BatteryStatus extends Equatable {
  const BatteryStatus({
    required this.percentage,
    this.isCharging = false,
    this.voltage,
    this.current,
    this.temperature,
    this.estimatedRuntimeMinutes,
  });

  final int percentage;
  final bool isCharging;
  final double? voltage;
  final double? current;
  final double? temperature;
  final int? estimatedRuntimeMinutes;

  factory BatteryStatus.fromJson(Map<String, dynamic> json) {
    return BatteryStatus(
      percentage: json['percentage'] as int,
      isCharging: json['is_charging'] as bool? ?? false,
      voltage: (json['voltage'] as num?)?.toDouble(),
      current: (json['current'] as num?)?.toDouble(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      estimatedRuntimeMinutes: json['estimated_runtime_minutes'] as int?,
    );
  }

  /// Battery level category for UI display.
  BatteryLevel get level {
    if (percentage > 60) return BatteryLevel.high;
    if (percentage > 30) return BatteryLevel.medium;
    if (percentage > 10) return BatteryLevel.low;
    return BatteryLevel.critical;
  }

  @override
  List<Object?> get props => [
    percentage,
    isCharging,
    voltage,
    current,
    temperature,
    estimatedRuntimeMinutes,
  ];
}

/// Battery level categories.
enum BatteryLevel { high, medium, low, critical }

/// Robot location information.
class LocationData extends Equatable {
  const LocationData({
    required this.floor,
    this.zone,
    this.room,
    this.x,
    this.y,
    this.heading,
  });

  final int floor;
  final String? zone;
  final String? room;
  final double? x;
  final double? y;
  final double? heading;

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      floor: json['floor'] as int,
      zone: json['zone'] as String?,
      room: json['room'] as String?,
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
    );
  }

  /// Formatted location string for display.
  String get displayString {
    final parts = <String>['Floor $floor'];
    if (zone != null) parts.add('Zone $zone');
    if (room != null) parts.add(room!);
    return parts.join(' • ');
  }

  @override
  List<Object?> get props => [floor, zone, room, x, y, heading];
}

/// Robot motion information.
class MotionData extends Equatable {
  const MotionData({
    this.linearVelocity = 0.0,
    this.angularVelocity = 0.0,
    this.isMoving = false,
    this.targetFloor,
    this.targetZone,
  });

  final double linearVelocity;
  final double angularVelocity;
  final bool isMoving;
  final int? targetFloor;
  final String? targetZone;

  factory MotionData.fromJson(Map<String, dynamic> json) {
    return MotionData(
      linearVelocity: (json['linear_velocity'] as num?)?.toDouble() ?? 0.0,
      angularVelocity: (json['angular_velocity'] as num?)?.toDouble() ?? 0.0,
      isMoving: json['is_moving'] as bool? ?? false,
      targetFloor: json['target_floor'] as int?,
      targetZone: json['target_zone'] as String?,
    );
  }

  /// Speed in human readable format.
  String get speedDisplay => '${linearVelocity.toStringAsFixed(2)} m/s';

  @override
  List<Object?> get props => [
    linearVelocity,
    angularVelocity,
    isMoving,
    targetFloor,
    targetZone,
  ];
}

/// Environmental sensor readings.
class SensorData extends Equatable {
  const SensorData({
    this.frontDistance,
    this.rearDistance,
    this.leftDistance,
    this.rightDistance,
    this.cliffDetected = false,
    this.stairDetected = false,
    this.ambientTemperature,
    this.humidity,
  });

  final double? frontDistance;
  final double? rearDistance;
  final double? leftDistance;
  final double? rightDistance;
  final bool cliffDetected;
  final bool stairDetected;
  final double? ambientTemperature;
  final double? humidity;

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      frontDistance: (json['front_distance'] as num?)?.toDouble(),
      rearDistance: (json['rear_distance'] as num?)?.toDouble(),
      leftDistance: (json['left_distance'] as num?)?.toDouble(),
      rightDistance: (json['right_distance'] as num?)?.toDouble(),
      cliffDetected: json['cliff_detected'] as bool? ?? false,
      stairDetected: json['stair_detected'] as bool? ?? false,
      ambientTemperature: (json['ambient_temperature'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [
    frontDistance,
    rearDistance,
    leftDistance,
    rightDistance,
    cliffDetected,
    stairDetected,
    ambientTemperature,
    humidity,
  ];
}

/// System health metrics.
class SystemHealth extends Equatable {
  const SystemHealth({
    this.cpuUsage,
    this.memoryUsage,
    this.diskUsage,
    this.wifiSignal,
    this.uptimeSeconds,
  });

  final double? cpuUsage;
  final double? memoryUsage;
  final double? diskUsage;
  final int? wifiSignal;
  final int? uptimeSeconds;

  factory SystemHealth.fromJson(Map<String, dynamic> json) {
    return SystemHealth(
      cpuUsage: (json['cpu_usage'] as num?)?.toDouble(),
      memoryUsage: (json['memory_usage'] as num?)?.toDouble(),
      diskUsage: (json['disk_usage'] as num?)?.toDouble(),
      wifiSignal: json['wifi_signal'] as int?,
      uptimeSeconds: json['uptime_seconds'] as int?,
    );
  }

  /// WiFi signal strength description.
  String get wifiStrengthLabel {
    if (wifiSignal == null) return 'Unknown';
    if (wifiSignal! > -50) return 'Excellent';
    if (wifiSignal! > -60) return 'Good';
    if (wifiSignal! > -70) return 'Fair';
    return 'Weak';
  }

  /// Uptime in human readable format.
  String get uptimeDisplay {
    if (uptimeSeconds == null) return 'Unknown';
    final hours = uptimeSeconds! ~/ 3600;
    final minutes = (uptimeSeconds! % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  @override
  List<Object?> get props => [
    cpuUsage,
    memoryUsage,
    diskUsage,
    wifiSignal,
    uptimeSeconds,
  ];
}

/// Complete telemetry packet from robot.
class TelemetryData extends Equatable {
  const TelemetryData({
    required this.robotId,
    required this.timestamp,
    required this.state,
    required this.battery,
    required this.location,
    required this.motion,
    required this.containerState,
    required this.connectivity,
    this.sensors,
    this.system,
    this.activeDeliveryId,
    this.errorCode,
    this.errorMessage,
  });

  final String robotId;
  final DateTime timestamp;
  final RobotState state;
  final BatteryStatus battery;
  final LocationData location;
  final MotionData motion;
  final ContainerState containerState;
  final ConnectivityStatus connectivity;
  final SensorData? sensors;
  final SystemHealth? system;
  final int? activeDeliveryId;
  final String? errorCode;
  final String? errorMessage;

  factory TelemetryData.fromJson(Map<String, dynamic> json) {
    return TelemetryData(
      robotId: json['robot_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      state: RobotState.fromString(json['state'] as String),
      battery: BatteryStatus.fromJson(json['battery'] as Map<String, dynamic>),
      location: LocationData.fromJson(json['location'] as Map<String, dynamic>),
      motion: MotionData.fromJson(json['motion'] as Map<String, dynamic>),
      containerState: ContainerState.fromString(
        json['container_state'] as String,
      ),
      connectivity: ConnectivityStatus.fromString(
        json['connectivity'] as String,
      ),
      sensors: json['sensors'] != null
          ? SensorData.fromJson(json['sensors'] as Map<String, dynamic>)
          : null,
      system: json['system'] != null
          ? SystemHealth.fromJson(json['system'] as Map<String, dynamic>)
          : null,
      activeDeliveryId: json['active_delivery_id'] as int?,
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
    );
  }

  /// Whether the robot has an active error.
  bool get hasError => errorCode != null || state == RobotState.error;

  /// Whether the robot is currently busy with a delivery.
  bool get isBusy => activeDeliveryId != null || state.isActive;

  @override
  List<Object?> get props => [
    robotId,
    timestamp,
    state,
    battery,
    location,
    motion,
    containerState,
    connectivity,
    sensors,
    system,
    activeDeliveryId,
    errorCode,
    errorMessage,
  ];
}
