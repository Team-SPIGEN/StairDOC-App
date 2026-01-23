/// Access log model for container lock/unlock events.
///
/// Maps to the backend AccessLog schema and represents a single
/// access control event (lock, unlock, or auto-lock).
library;

import 'package:equatable/equatable.dart';

/// Enum representing the type of access action.
enum AccessAction {
  lock,
  unlock,
  autoLock;

  factory AccessAction.fromString(String value) {
    return switch (value.toLowerCase()) {
      'lock' => AccessAction.lock,
      'unlock' => AccessAction.unlock,
      'auto_lock' || 'autolock' => AccessAction.autoLock,
      _ => AccessAction.lock,
    };
  }

  String get displayName => switch (this) {
    AccessAction.lock => 'Locked',
    AccessAction.unlock => 'Unlocked',
    AccessAction.autoLock => 'Auto-locked',
  };
}

/// Enum representing how the access action was triggered.
enum AccessMethod {
  app,
  rfid,
  voice,
  auto;

  factory AccessMethod.fromString(String value) {
    return switch (value.toLowerCase()) {
      'app' => AccessMethod.app,
      'rfid' => AccessMethod.rfid,
      'voice' => AccessMethod.voice,
      'auto' => AccessMethod.auto,
      _ => AccessMethod.app,
    };
  }

  String get displayName => switch (this) {
    AccessMethod.app => 'Mobile App',
    AccessMethod.rfid => 'RFID Card',
    AccessMethod.voice => 'Voice Command',
    AccessMethod.auto => 'Automatic',
  };
}

/// Enum representing the outcome of an access action.
enum AccessStatus {
  success,
  failed,
  denied;

  factory AccessStatus.fromString(String value) {
    return switch (value.toLowerCase()) {
      'success' => AccessStatus.success,
      'failed' => AccessStatus.failed,
      'denied' => AccessStatus.denied,
      _ => AccessStatus.success,
    };
  }

  bool get isSuccess => this == AccessStatus.success;
}

/// A single access log entry from the backend.
class AccessLogEntry extends Equatable {
  const AccessLogEntry({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.location,
    required this.timestamp,
    required this.status,
    required this.method,
    this.floor,
    this.zone,
    this.errorMessage,
    this.photoUrl,
  });

  /// Unique identifier for this log entry.
  final int id;

  /// ID of the user who performed the action.
  final String userId;

  /// Display name of the user.
  final String userName;

  /// Type of action performed.
  final AccessAction action;

  /// Human-readable location description.
  final String location;

  /// Floor number, if available.
  final int? floor;

  /// Zone identifier, if available.
  final String? zone;

  /// When the action occurred (UTC).
  final DateTime timestamp;

  /// Outcome of the action.
  final AccessStatus status;

  /// How the action was triggered.
  final AccessMethod method;

  /// Error message if status != success.
  final String? errorMessage;

  /// URL to snapshot captured during unlock, if any.
  final String? photoUrl;

  /// Create from JSON response.
  factory AccessLogEntry.fromJson(Map<String, dynamic> json) {
    return AccessLogEntry(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? 'Unknown',
      action: AccessAction.fromString(json['action'] as String),
      location: json['location'] as String? ?? 'Unknown',
      floor: json['floor'] as int?,
      zone: json['zone'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: AccessStatus.fromString(json['status'] as String),
      method: AccessMethod.fromString(json['method'] as String? ?? 'app'),
      errorMessage: json['error_message'] as String?,
      photoUrl: json['photo_url'] as String?,
    );
  }

  /// Convert to JSON for API requests.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'action': action.name,
      'location': location,
      'floor': floor,
      'zone': zone,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'method': method.name,
      'error_message': errorMessage,
      'photo_url': photoUrl,
    };
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    userName,
    action,
    location,
    floor,
    zone,
    timestamp,
    status,
    method,
    errorMessage,
    photoUrl,
  ];
}

/// Response from lock/unlock endpoints.
class LockUnlockResponse extends Equatable {
  const LockUnlockResponse({
    required this.status,
    required this.action,
    required this.timestamp,
    required this.message,
    required this.logId,
  });

  final String status;
  final AccessAction action;
  final DateTime timestamp;
  final String message;
  final int logId;

  factory LockUnlockResponse.fromJson(Map<String, dynamic> json) {
    return LockUnlockResponse(
      status: json['status'] as String,
      action: AccessAction.fromString(json['action'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      message: json['message'] as String,
      logId: json['log_id'] as int,
    );
  }

  bool get isSuccess => status == 'success';

  @override
  List<Object?> get props => [status, action, timestamp, message, logId];
}

/// Container status from the backend.
class ContainerStatus extends Equatable {
  const ContainerStatus({
    required this.isLocked,
    this.lastAction,
    this.lastActionBy,
    this.lastActionAt,
    this.robotId,
  });

  final bool isLocked;
  final AccessAction? lastAction;
  final String? lastActionBy;
  final DateTime? lastActionAt;
  final String? robotId;

  factory ContainerStatus.fromJson(Map<String, dynamic> json) {
    return ContainerStatus(
      isLocked: json['is_locked'] as bool,
      lastAction: json['last_action'] != null
          ? AccessAction.fromString(json['last_action'] as String)
          : null,
      lastActionBy: json['last_action_by'] as String?,
      lastActionAt: json['last_action_at'] != null
          ? DateTime.parse(json['last_action_at'] as String)
          : null,
      robotId: json['robot_id'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    isLocked,
    lastAction,
    lastActionBy,
    lastActionAt,
    robotId,
  ];
}
