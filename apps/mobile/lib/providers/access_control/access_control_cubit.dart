/// Cubit for managing container access control state.
///
/// Handles:
/// - Locking and unlocking operations
/// - Fetching and paginating access logs
/// - Container status updates
library;

import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';

import '../../models/access_log.dart';
import '../../services/container_access_service.dart';
import 'access_control_state.dart';

export 'access_control_state.dart';

/// Cubit for container access control operations.
///
/// Usage:
/// ```dart
/// BlocProvider(
///   create: (context) => AccessControlCubit(
///     containerAccessService: context.read<ContainerAccessService>(),
///   )..initialize(),
///   child: MyWidget(),
/// )
/// ```
class AccessControlCubit extends Cubit<AccessControlState> {
  AccessControlCubit({required ContainerAccessService containerAccessService})
    : _service = containerAccessService,
      super(const AccessControlState());

  final ContainerAccessService _service;

  /// Initialize the cubit by fetching current status and recent logs.
  Future<void> initialize() async {
    emit(state.copyWith(status: AccessControlStatus.loading));

    try {
      // Fetch status and logs in parallel
      final results = await Future.wait([
        _service.getStatus(),
        _service.getAccessLogs(limit: 20),
      ]);

      final containerStatus = results[0] as ContainerStatus;
      final logsResponse = results[1] as AccessLogsResponse;

      emit(
        state.copyWith(
          status: AccessControlStatus.success,
          containerStatus: containerStatus,
          logs: logsResponse.logs,
          totalLogs: logsResponse.total,
          hasMoreLogs: logsResponse.hasMore,
          clearError: true,
        ),
      );
    } on ContainerAccessException catch (e) {
      developer.log(
        'Failed to initialize access control',
        name: 'AccessControlCubit',
        error: e,
      );
      emit(
        state.copyWith(
          status: AccessControlStatus.error,
          errorMessage: e.message,
        ),
      );
    }
  }

  /// Refresh the container status from hardware.
  Future<void> refreshStatus() async {
    try {
      final status = await _service.getStatus();
      emit(state.copyWith(containerStatus: status, clearError: true));
    } on ContainerAccessException catch (e) {
      developer.log(
        'Failed to refresh status',
        name: 'AccessControlCubit',
        error: e,
      );
      emit(state.copyWith(errorMessage: e.message));
    }
  }

  /// Unlock the container.
  ///
  /// Parameters:
  /// - [location]: Human-readable location string
  /// - [floor]: Floor number
  /// - [zone]: Zone identifier
  Future<void> unlock({String? location, int? floor, String? zone}) async {
    if (state.isOperationInProgress) return;

    emit(state.copyWith(isUnlocking: true, clearError: true));

    try {
      final response = await _service.unlock(
        location: location,
        floor: floor,
        zone: zone,
      );

      // Update status and refresh logs
      final status = await _service.getStatus();
      final logsResponse = await _service.getAccessLogs(limit: 20);

      emit(
        state.copyWith(
          status: AccessControlStatus.success,
          containerStatus: status,
          logs: logsResponse.logs,
          totalLogs: logsResponse.total,
          hasMoreLogs: logsResponse.hasMore,
          lastAction: AccessAction.unlock,
          lastActionTime: response.timestamp,
          isUnlocking: false,
        ),
      );
    } on ContainerAccessException catch (e) {
      developer.log('Unlock failed', name: 'AccessControlCubit', error: e);
      emit(
        state.copyWith(
          status: AccessControlStatus.error,
          errorMessage: e.message,
          isUnlocking: false,
        ),
      );
    }
  }

  /// Lock the container.
  ///
  /// Parameters:
  /// - [location]: Human-readable location string
  /// - [floor]: Floor number
  /// - [zone]: Zone identifier
  Future<void> lock({String? location, int? floor, String? zone}) async {
    if (state.isOperationInProgress) return;

    emit(state.copyWith(isLocking: true, clearError: true));

    try {
      final response = await _service.lock(
        location: location,
        floor: floor,
        zone: zone,
      );

      // Update status and refresh logs
      final status = await _service.getStatus();
      final logsResponse = await _service.getAccessLogs(limit: 20);

      emit(
        state.copyWith(
          status: AccessControlStatus.success,
          containerStatus: status,
          logs: logsResponse.logs,
          totalLogs: logsResponse.total,
          hasMoreLogs: logsResponse.hasMore,
          lastAction: AccessAction.lock,
          lastActionTime: response.timestamp,
          isLocking: false,
        ),
      );
    } on ContainerAccessException catch (e) {
      developer.log('Lock failed', name: 'AccessControlCubit', error: e);
      emit(
        state.copyWith(
          status: AccessControlStatus.error,
          errorMessage: e.message,
          isLocking: false,
        ),
      );
    }
  }

  /// Load more access logs for pagination.
  Future<void> loadMoreLogs() async {
    if (!state.hasMoreLogs || state.status == AccessControlStatus.loading) {
      return;
    }

    try {
      final logsResponse = await _service.getAccessLogs(
        limit: 20,
        offset: state.logs.length,
      );

      emit(
        state.copyWith(
          logs: [...state.logs, ...logsResponse.logs],
          totalLogs: logsResponse.total,
          hasMoreLogs: logsResponse.hasMore,
        ),
      );
    } on ContainerAccessException catch (e) {
      developer.log(
        'Load more logs failed',
        name: 'AccessControlCubit',
        error: e,
      );
      emit(state.copyWith(errorMessage: e.message));
    }
  }

  /// Refresh the access logs list.
  Future<void> refreshLogs() async {
    emit(state.copyWith(status: AccessControlStatus.loading));

    try {
      final logsResponse = await _service.getAccessLogs(limit: 20);

      emit(
        state.copyWith(
          status: AccessControlStatus.success,
          logs: logsResponse.logs,
          totalLogs: logsResponse.total,
          hasMoreLogs: logsResponse.hasMore,
          clearError: true,
        ),
      );
    } on ContainerAccessException catch (e) {
      developer.log(
        'Refresh logs failed',
        name: 'AccessControlCubit',
        error: e,
      );
      emit(
        state.copyWith(
          status: AccessControlStatus.error,
          errorMessage: e.message,
        ),
      );
    }
  }

  /// Clear any error state.
  void clearError() {
    emit(state.copyWith(clearError: true));
  }
}
