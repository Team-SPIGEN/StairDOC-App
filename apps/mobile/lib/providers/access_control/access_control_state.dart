/// Access control state for BLoC state management.
///
/// Represents the state of container access operations including:
/// - Current container status
/// - Access log history
/// - Loading and error states
library;

import 'package:equatable/equatable.dart';

import '../../models/access_log.dart';

/// Possible states for access control operations.
enum AccessControlStatus { initial, loading, success, error }

/// State for the [AccessControlCubit].
class AccessControlState extends Equatable {
  const AccessControlState({
    this.status = AccessControlStatus.initial,
    this.containerStatus,
    this.logs = const [],
    this.totalLogs = 0,
    this.hasMoreLogs = false,
    this.errorMessage,
    this.lastAction,
    this.lastActionTime,
    this.isLocking = false,
    this.isUnlocking = false,
  });

  /// Current operation status.
  final AccessControlStatus status;

  /// Current container lock status from hardware.
  final ContainerStatus? containerStatus;

  /// List of access log entries.
  final List<AccessLogEntry> logs;

  /// Total number of logs available (for pagination).
  final int totalLogs;

  /// Whether more logs are available to load.
  final bool hasMoreLogs;

  /// Error message if status == error.
  final String? errorMessage;

  /// Most recent action performed by the user.
  final AccessAction? lastAction;

  /// When the most recent action was performed.
  final DateTime? lastActionTime;

  /// Whether a lock operation is in progress.
  final bool isLocking;

  /// Whether an unlock operation is in progress.
  final bool isUnlocking;

  /// Whether any lock/unlock operation is in progress.
  bool get isOperationInProgress => isLocking || isUnlocking;

  /// Whether the container is currently locked.
  bool get isLocked => containerStatus?.isLocked ?? true;

  /// Create a copy with updated fields.
  AccessControlState copyWith({
    AccessControlStatus? status,
    ContainerStatus? containerStatus,
    List<AccessLogEntry>? logs,
    int? totalLogs,
    bool? hasMoreLogs,
    String? errorMessage,
    AccessAction? lastAction,
    DateTime? lastActionTime,
    bool? isLocking,
    bool? isUnlocking,
    bool clearError = false,
  }) {
    return AccessControlState(
      status: status ?? this.status,
      containerStatus: containerStatus ?? this.containerStatus,
      logs: logs ?? this.logs,
      totalLogs: totalLogs ?? this.totalLogs,
      hasMoreLogs: hasMoreLogs ?? this.hasMoreLogs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastAction: lastAction ?? this.lastAction,
      lastActionTime: lastActionTime ?? this.lastActionTime,
      isLocking: isLocking ?? this.isLocking,
      isUnlocking: isUnlocking ?? this.isUnlocking,
    );
  }

  @override
  List<Object?> get props => [
    status,
    containerStatus,
    logs,
    totalLogs,
    hasMoreLogs,
    errorMessage,
    lastAction,
    lastActionTime,
    isLocking,
    isUnlocking,
  ];
}
