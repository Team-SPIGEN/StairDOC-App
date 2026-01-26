/// Camera state management using BLoC pattern.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../models/camera.dart';
import '../services/camera_service.dart';

// ===========================================================================
// Events
// ===========================================================================

abstract class CameraEvent extends Equatable {
  const CameraEvent();

  @override
  List<Object?> get props => [];
}

class CameraStartStreamRequested extends CameraEvent {
  const CameraStartStreamRequested({
    required this.robotId,
    this.cameraId,
    this.quality = StreamQuality.medium,
    this.format = StreamFormat.mjpeg,
  });

  final String robotId;
  final String? cameraId;
  final StreamQuality quality;
  final StreamFormat format;

  @override
  List<Object?> get props => [robotId, cameraId, quality, format];
}

class CameraStopStreamRequested extends CameraEvent {
  const CameraStopStreamRequested();
}

class CameraFrameReceived extends CameraEvent {
  const CameraFrameReceived(this.frame);

  final Uint8List frame;

  @override
  List<Object?> get props => [frame.length];
}

class CameraStatusChanged extends CameraEvent {
  const CameraStatusChanged(this.status);

  final CameraStatus status;

  @override
  List<Object?> get props => [status];
}

class CameraLatencyUpdated extends CameraEvent {
  const CameraLatencyUpdated(this.latency);

  final double latency;

  @override
  List<Object?> get props => [latency];
}

class CameraSnapshotRequested extends CameraEvent {
  const CameraSnapshotRequested({
    required this.robotId,
    this.cameraId,
    this.quality = StreamQuality.high,
  });

  final String robotId;
  final String? cameraId;
  final StreamQuality quality;

  @override
  List<Object?> get props => [robotId, cameraId, quality];
}

class CameraQualityChanged extends CameraEvent {
  const CameraQualityChanged(this.quality);

  final StreamQuality quality;

  @override
  List<Object?> get props => [quality];
}

class CameraSettingsRequested extends CameraEvent {
  const CameraSettingsRequested(this.cameraId);

  final String cameraId;

  @override
  List<Object?> get props => [cameraId];
}

class CameraSettingsUpdated extends CameraEvent {
  const CameraSettingsUpdated({required this.cameraId, required this.updates});

  final String cameraId;
  final Map<String, dynamic> updates;

  @override
  List<Object?> get props => [cameraId, updates];
}

class CameraStatsRequested extends CameraEvent {
  const CameraStatsRequested(this.cameraId);

  final String cameraId;

  @override
  List<Object?> get props => [cameraId];
}

// ===========================================================================
// State
// ===========================================================================

enum CameraStateStatus { initial, connecting, streaming, paused, error }

class CameraState extends Equatable {
  const CameraState({
    this.status = CameraStateStatus.initial,
    this.cameraStatus = CameraStatus.offline,
    this.currentFrame,
    this.lastSnapshot,
    this.quality = StreamQuality.medium,
    this.settings,
    this.stats,
    this.latency = 0,
    this.frameCount = 0,
    this.sessionId,
    this.errorMessage,
    this.robotId,
    this.cameraId,
  });

  final CameraStateStatus status;
  final CameraStatus cameraStatus;
  final Uint8List? currentFrame;
  final Snapshot? lastSnapshot;
  final StreamQuality quality;
  final CameraSettings? settings;
  final CameraStats? stats;
  final double latency;
  final int frameCount;
  final String? sessionId;
  final String? errorMessage;
  final String? robotId;
  final String? cameraId;

  bool get isStreaming => status == CameraStateStatus.streaming;
  bool get isConnecting => status == CameraStateStatus.connecting;
  bool get hasError => status == CameraStateStatus.error;
  bool get isLowLatency => latency > 0 && latency < 500;

  CameraState copyWith({
    CameraStateStatus? status,
    CameraStatus? cameraStatus,
    Uint8List? currentFrame,
    Snapshot? lastSnapshot,
    StreamQuality? quality,
    CameraSettings? settings,
    CameraStats? stats,
    double? latency,
    int? frameCount,
    String? sessionId,
    String? errorMessage,
    String? robotId,
    String? cameraId,
  }) {
    return CameraState(
      status: status ?? this.status,
      cameraStatus: cameraStatus ?? this.cameraStatus,
      currentFrame: currentFrame ?? this.currentFrame,
      lastSnapshot: lastSnapshot ?? this.lastSnapshot,
      quality: quality ?? this.quality,
      settings: settings ?? this.settings,
      stats: stats ?? this.stats,
      latency: latency ?? this.latency,
      frameCount: frameCount ?? this.frameCount,
      sessionId: sessionId ?? this.sessionId,
      errorMessage: errorMessage ?? this.errorMessage,
      robotId: robotId ?? this.robotId,
      cameraId: cameraId ?? this.cameraId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    cameraStatus,
    currentFrame?.length,
    lastSnapshot,
    quality,
    settings,
    stats,
    latency,
    frameCount,
    sessionId,
    errorMessage,
    robotId,
    cameraId,
  ];
}

// ===========================================================================
// Cubit
// ===========================================================================

class CameraCubit extends Cubit<CameraState> {
  CameraCubit({CameraService? cameraService})
    : _cameraService = cameraService ?? CameraService(),
      super(const CameraState()) {
    _init();
  }

  final CameraService _cameraService;

  StreamSubscription<Uint8List>? _frameSubscription;
  StreamSubscription<CameraStatus>? _statusSubscription;
  StreamSubscription<double>? _latencySubscription;

  void _init() {
    _frameSubscription = _cameraService.frameStream.listen(_onFrameReceived);
    _statusSubscription = _cameraService.statusStream.listen(_onStatusChanged);
    _latencySubscription = _cameraService.latencyStream.listen(
      _onLatencyUpdated,
    );
  }

  // ===========================================================================
  // Stream Control
  // ===========================================================================

  /// Start streaming from a robot's camera.
  Future<void> startStream({
    required String robotId,
    String? cameraId,
    StreamQuality? quality,
    StreamFormat format = StreamFormat.mjpeg,
  }) async {
    final streamQuality = quality ?? state.quality;

    emit(
      state.copyWith(
        status: CameraStateStatus.connecting,
        robotId: robotId,
        cameraId: cameraId,
        quality: streamQuality,
        errorMessage: null,
      ),
    );

    try {
      final response = await _cameraService.startStream(
        robotId: robotId,
        cameraId: cameraId,
        quality: streamQuality,
        format: format,
      );

      emit(
        state.copyWith(
          status: CameraStateStatus.streaming,
          sessionId: response.sessionId,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: CameraStateStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Stop the current stream.
  Future<void> stopStream() async {
    await _cameraService.stopStream();

    emit(
      state.copyWith(
        status: CameraStateStatus.initial,
        cameraStatus: CameraStatus.offline,
        currentFrame: null,
        sessionId: null,
        latency: 0,
        frameCount: 0,
      ),
    );
  }

  /// Change stream quality.
  Future<void> changeQuality(StreamQuality quality) async {
    if (!state.isStreaming || state.robotId == null) {
      emit(state.copyWith(quality: quality));
      return;
    }

    // Restart stream with new quality
    await startStream(
      robotId: state.robotId!,
      cameraId: state.cameraId,
      quality: quality,
    );
  }

  // ===========================================================================
  // Callbacks
  // ===========================================================================

  void _onFrameReceived(Uint8List frame) {
    emit(state.copyWith(currentFrame: frame, frameCount: state.frameCount + 1));
  }

  void _onStatusChanged(CameraStatus status) {
    CameraStateStatus stateStatus;
    switch (status) {
      case CameraStatus.connecting:
        stateStatus = CameraStateStatus.connecting;
        break;
      case CameraStatus.streaming:
        stateStatus = CameraStateStatus.streaming;
        break;
      case CameraStatus.error:
        stateStatus = CameraStateStatus.error;
        break;
      case CameraStatus.online:
        stateStatus = CameraStateStatus.initial;
        break;
      case CameraStatus.offline:
      case CameraStatus.idle:
        stateStatus = CameraStateStatus.initial;
        break;
    }

    emit(state.copyWith(cameraStatus: status, status: stateStatus));
  }

  void _onLatencyUpdated(double latency) {
    emit(state.copyWith(latency: latency));
  }

  // ===========================================================================
  // Snapshots
  // ===========================================================================

  /// Capture a snapshot.
  Future<Snapshot?> captureSnapshot() async {
    if (state.robotId == null) return null;

    try {
      final snapshot = await _cameraService.captureSnapshot(
        robotId: state.robotId!,
        cameraId: state.cameraId,
        quality: StreamQuality.high,
      );

      emit(state.copyWith(lastSnapshot: snapshot));
      return snapshot;
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
      return null;
    }
  }

  // ===========================================================================
  // Settings
  // ===========================================================================

  /// Load camera settings.
  Future<void> loadSettings(String cameraId) async {
    try {
      final settings = await _cameraService.getSettings(cameraId);
      emit(state.copyWith(settings: settings));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  /// Update camera settings.
  Future<void> updateSettings(
    String cameraId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final settings = await _cameraService.updateSettings(cameraId, updates);
      emit(state.copyWith(settings: settings));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  // ===========================================================================
  // Statistics
  // ===========================================================================

  /// Load camera stats.
  Future<void> loadStats(String cameraId) async {
    try {
      final stats = await _cameraService.getStats(cameraId);
      emit(state.copyWith(stats: stats));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _frameSubscription?.cancel();
    _statusSubscription?.cancel();
    _latencySubscription?.cancel();
    _cameraService.dispose();
    return super.close();
  }
}
