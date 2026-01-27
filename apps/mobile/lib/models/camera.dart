/// Camera models for live video streaming.
///
/// Matches backend schemas in services/api/app/schemas/camera.py
library;

import 'package:flutter/material.dart';

/// Camera connection status.
enum CameraStatus {
  online('online'),
  offline('offline'),
  connecting('connecting'),
  error('error'),
  streaming('streaming'),
  idle('idle');

  const CameraStatus(this.value);
  final String value;

  static CameraStatus fromString(String value) {
    return CameraStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CameraStatus.offline,
    );
  }

  /// Get an icon for this status.
  IconData get icon {
    switch (this) {
      case CameraStatus.online:
        return Icons.videocam;
      case CameraStatus.offline:
        return Icons.videocam_off;
      case CameraStatus.connecting:
        return Icons.sync;
      case CameraStatus.error:
        return Icons.error_outline;
      case CameraStatus.streaming:
        return Icons.play_circle;
      case CameraStatus.idle:
        return Icons.pause_circle;
    }
  }

  /// Get a color for this status.
  Color get color {
    switch (this) {
      case CameraStatus.online:
        return Colors.green;
      case CameraStatus.offline:
        return Colors.grey;
      case CameraStatus.connecting:
        return Colors.orange;
      case CameraStatus.error:
        return Colors.red;
      case CameraStatus.streaming:
        return Colors.blue;
      case CameraStatus.idle:
        return Colors.amber;
    }
  }

  /// Get a label for this status.
  String get label {
    switch (this) {
      case CameraStatus.online:
        return 'Online';
      case CameraStatus.offline:
        return 'Offline';
      case CameraStatus.connecting:
        return 'Connecting';
      case CameraStatus.error:
        return 'Error';
      case CameraStatus.streaming:
        return 'Streaming';
      case CameraStatus.idle:
        return 'Idle';
    }
  }
}

/// Video stream quality presets.
enum StreamQuality {
  low('low'),
  medium('medium'),
  high('high'),
  auto('auto');

  const StreamQuality(this.value);
  final String value;

  static StreamQuality fromString(String value) {
    return StreamQuality.values.firstWhere(
      (e) => e.value == value,
      orElse: () => StreamQuality.medium,
    );
  }

  String get displayName {
    switch (this) {
      case StreamQuality.low:
        return '320x240 (Low)';
      case StreamQuality.medium:
        return '640x480 (Medium)';
      case StreamQuality.high:
        return '1280x720 (HD)';
      case StreamQuality.auto:
        return 'Auto';
    }
  }

  /// Get an icon for this quality level.
  IconData get icon {
    switch (this) {
      case StreamQuality.low:
        return Icons.sd;
      case StreamQuality.medium:
        return Icons.hd;
      case StreamQuality.high:
        return Icons.high_quality;
      case StreamQuality.auto:
        return Icons.auto_awesome;
    }
  }

  /// Get a label for this quality level.
  String get label {
    switch (this) {
      case StreamQuality.low:
        return 'Low';
      case StreamQuality.medium:
        return 'Medium';
      case StreamQuality.high:
        return 'High';
      case StreamQuality.auto:
        return 'Auto';
    }
  }

  /// Get a description for this quality level.
  String get description {
    switch (this) {
      case StreamQuality.low:
        return '320x240 at 10fps - minimal bandwidth';
      case StreamQuality.medium:
        return '640x480 at 15fps - balanced quality';
      case StreamQuality.high:
        return '1280x720 at 25fps - best quality';
      case StreamQuality.auto:
        return 'Automatically adjusts based on connection';
    }
  }
}

/// Supported stream formats.
enum StreamFormat {
  mjpeg('mjpeg'),
  webrtc('webrtc'),
  hls('hls');

  const StreamFormat(this.value);
  final String value;

  static StreamFormat fromString(String value) {
    return StreamFormat.values.firstWhere(
      (e) => e.value == value,
      orElse: () => StreamFormat.mjpeg,
    );
  }
}

/// Information about a camera.
class CameraInfo {
  CameraInfo({
    required this.id,
    required this.robotId,
    this.name = 'Main Camera',
    this.status = CameraStatus.offline,
    this.resolutionWidth = 640,
    this.resolutionHeight = 480,
    this.fps = 15,
    this.format = StreamFormat.mjpeg,
    this.lastFrameAt,
    this.streamUrl,
  });

  final String id;
  final String robotId;
  final String name;
  final CameraStatus status;
  final int resolutionWidth;
  final int resolutionHeight;
  final int fps;
  final StreamFormat format;
  final DateTime? lastFrameAt;
  final String? streamUrl;

  String get resolution => '${resolutionWidth}x$resolutionHeight';

  factory CameraInfo.fromJson(Map<String, dynamic> json) {
    return CameraInfo(
      id: json['id'] as String,
      robotId: json['robot_id'] as String,
      name: json['name'] as String? ?? 'Main Camera',
      status: CameraStatus.fromString(json['status'] as String? ?? 'offline'),
      resolutionWidth: json['resolution_width'] as int? ?? 640,
      resolutionHeight: json['resolution_height'] as int? ?? 480,
      fps: json['fps'] as int? ?? 15,
      format: StreamFormat.fromString(json['format'] as String? ?? 'mjpeg'),
      lastFrameAt: json['last_frame_at'] != null
          ? DateTime.parse(json['last_frame_at'] as String)
          : null,
      streamUrl: json['stream_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'robot_id': robotId,
      'name': name,
      'status': status.value,
      'resolution_width': resolutionWidth,
      'resolution_height': resolutionHeight,
      'fps': fps,
      'format': format.value,
      'last_frame_at': lastFrameAt?.toIso8601String(),
      'stream_url': streamUrl,
    };
  }

  CameraInfo copyWith({
    String? id,
    String? robotId,
    String? name,
    CameraStatus? status,
    int? resolutionWidth,
    int? resolutionHeight,
    int? fps,
    StreamFormat? format,
    DateTime? lastFrameAt,
    String? streamUrl,
  }) {
    return CameraInfo(
      id: id ?? this.id,
      robotId: robotId ?? this.robotId,
      name: name ?? this.name,
      status: status ?? this.status,
      resolutionWidth: resolutionWidth ?? this.resolutionWidth,
      resolutionHeight: resolutionHeight ?? this.resolutionHeight,
      fps: fps ?? this.fps,
      format: format ?? this.format,
      lastFrameAt: lastFrameAt ?? this.lastFrameAt,
      streamUrl: streamUrl ?? this.streamUrl,
    );
  }
}

/// Camera configuration settings.
class CameraSettings {
  CameraSettings({
    this.quality = StreamQuality.medium,
    this.brightness = 50,
    this.contrast = 50,
    this.saturation = 50,
    this.autoExposure = true,
    this.autoFocus = true,
    this.nightVision = false,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.rotation = 0,
  });

  final StreamQuality quality;
  final int brightness;
  final int contrast;
  final int saturation;
  final bool autoExposure;
  final bool autoFocus;
  final bool nightVision;
  final bool flipHorizontal;
  final bool flipVertical;
  final int rotation;

  factory CameraSettings.fromJson(Map<String, dynamic> json) {
    return CameraSettings(
      quality: StreamQuality.fromString(json['quality'] as String? ?? 'medium'),
      brightness: json['brightness'] as int? ?? 50,
      contrast: json['contrast'] as int? ?? 50,
      saturation: json['saturation'] as int? ?? 50,
      autoExposure: json['auto_exposure'] as bool? ?? true,
      autoFocus: json['auto_focus'] as bool? ?? true,
      nightVision: json['night_vision'] as bool? ?? false,
      flipHorizontal: json['flip_horizontal'] as bool? ?? false,
      flipVertical: json['flip_vertical'] as bool? ?? false,
      rotation: json['rotation'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quality': quality.value,
      'brightness': brightness,
      'contrast': contrast,
      'saturation': saturation,
      'auto_exposure': autoExposure,
      'auto_focus': autoFocus,
      'night_vision': nightVision,
      'flip_horizontal': flipHorizontal,
      'flip_vertical': flipVertical,
      'rotation': rotation,
    };
  }

  CameraSettings copyWith({
    StreamQuality? quality,
    int? brightness,
    int? contrast,
    int? saturation,
    bool? autoExposure,
    bool? autoFocus,
    bool? nightVision,
    bool? flipHorizontal,
    bool? flipVertical,
    int? rotation,
  }) {
    return CameraSettings(
      quality: quality ?? this.quality,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      autoExposure: autoExposure ?? this.autoExposure,
      autoFocus: autoFocus ?? this.autoFocus,
      nightVision: nightVision ?? this.nightVision,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
      rotation: rotation ?? this.rotation,
    );
  }
}

/// Active stream session information.
class StreamSession {
  StreamSession({
    required this.sessionId,
    required this.cameraId,
    required this.robotId,
    required this.startedAt,
    required this.quality,
    required this.format,
    required this.streamUrl,
    this.viewers = 1,
    this.bytesSent = 0,
    this.framesSent = 0,
    this.avgLatencyMs = 0.0,
  });

  final String sessionId;
  final String cameraId;
  final String robotId;
  final DateTime startedAt;
  final StreamQuality quality;
  final StreamFormat format;
  final String streamUrl;
  final int viewers;
  final int bytesSent;
  final int framesSent;
  final double avgLatencyMs;

  factory StreamSession.fromJson(Map<String, dynamic> json) {
    return StreamSession(
      sessionId: json['session_id'] as String,
      cameraId: json['camera_id'] as String,
      robotId: json['robot_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      quality: StreamQuality.fromString(json['quality'] as String),
      format: StreamFormat.fromString(json['format'] as String),
      streamUrl: json['stream_url'] as String,
      viewers: json['viewers'] as int? ?? 1,
      bytesSent: json['bytes_sent'] as int? ?? 0,
      framesSent: json['frames_sent'] as int? ?? 0,
      avgLatencyMs: (json['avg_latency_ms'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Response with stream connection details.
class StreamResponse {
  StreamResponse({
    required this.sessionId,
    required this.streamUrl,
    required this.format,
    required this.quality,
    required this.estimatedLatencyMs,
    required this.expiresAt,
  });

  final String sessionId;
  final String streamUrl;
  final StreamFormat format;
  final StreamQuality quality;
  final int estimatedLatencyMs;
  final DateTime expiresAt;

  factory StreamResponse.fromJson(Map<String, dynamic> json) {
    return StreamResponse(
      sessionId: json['session_id'] as String,
      streamUrl: json['stream_url'] as String,
      format: StreamFormat.fromString(json['format'] as String),
      quality: StreamQuality.fromString(json['quality'] as String),
      estimatedLatencyMs: json['estimated_latency_ms'] as int? ?? 200,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

/// A captured snapshot from the camera.
class Snapshot {
  Snapshot({
    required this.id,
    required this.cameraId,
    required this.robotId,
    required this.capturedAt,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.width,
    required this.height,
    required this.fileSize,
    this.metadata,
  });

  final String id;
  final String cameraId;
  final String robotId;
  final DateTime capturedAt;
  final String imageUrl;
  final String? thumbnailUrl;
  final int width;
  final int height;
  final int fileSize;
  final Map<String, dynamic>? metadata;

  /// Alias for capturedAt for compatibility.
  DateTime get timestamp => capturedAt;

  factory Snapshot.fromJson(Map<String, dynamic> json) {
    return Snapshot(
      id: json['id'] as String,
      cameraId: json['camera_id'] as String,
      robotId: json['robot_id'] as String,
      capturedAt: DateTime.parse(json['captured_at'] as String),
      imageUrl: json['image_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      width: json['width'] as int,
      height: json['height'] as int,
      fileSize: json['file_size'] as int,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Camera streaming statistics.
class CameraStats {
  CameraStats({
    required this.cameraId,
    this.totalFrames = 0,
    this.droppedFrames = 0,
    this.avgFps = 0.0,
    this.avgLatencyMs = 0.0,
    this.minLatencyMs = 0.0,
    this.maxLatencyMs = 0.0,
    this.bandwidthKbps = 0.0,
    this.uptimeSeconds = 0,
    this.lastError,
  });

  final String cameraId;
  final int totalFrames;
  final int droppedFrames;
  final double avgFps;
  final double avgLatencyMs;
  final double minLatencyMs;
  final double maxLatencyMs;
  final double bandwidthKbps;
  final int uptimeSeconds;
  final String? lastError;

  factory CameraStats.fromJson(Map<String, dynamic> json) {
    return CameraStats(
      cameraId: json['camera_id'] as String,
      totalFrames: json['total_frames'] as int? ?? 0,
      droppedFrames: json['dropped_frames'] as int? ?? 0,
      avgFps: (json['avg_fps'] as num?)?.toDouble() ?? 0.0,
      avgLatencyMs: (json['avg_latency_ms'] as num?)?.toDouble() ?? 0.0,
      minLatencyMs: (json['min_latency_ms'] as num?)?.toDouble() ?? 0.0,
      maxLatencyMs: (json['max_latency_ms'] as num?)?.toDouble() ?? 0.0,
      bandwidthKbps: (json['bandwidth_kbps'] as num?)?.toDouble() ?? 0.0,
      uptimeSeconds: json['uptime_seconds'] as int? ?? 0,
      lastError: json['last_error'] as String?,
    );
  }
}
