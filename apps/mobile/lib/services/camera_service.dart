/// Camera service for live video streaming with low latency.
///
/// Provides MJPEG stream handling and snapshot capture.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/camera.dart';
import '../utils/api_endpoints.dart';

/// Service for managing camera streams and snapshots.
class CameraService {
  CameraService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  StreamSubscription<List<int>>? _mjpegSubscription;
  http.Client? _streamClient;

  /// Stream controller for MJPEG frames.
  final _frameController = StreamController<Uint8List>.broadcast();

  /// Stream controller for stream status.
  final _statusController = StreamController<CameraStatus>.broadcast();

  /// Stream controller for latency measurements.
  final _latencyController = StreamController<double>.broadcast();

  /// Stream of decoded JPEG frames.
  Stream<Uint8List> get frameStream => _frameController.stream;

  /// Stream of camera status changes.
  Stream<CameraStatus> get statusStream => _statusController.stream;

  /// Stream of latency measurements in milliseconds.
  Stream<double> get latencyStream => _latencyController.stream;

  String? _currentSessionId;
  String? _currentCameraId;
  bool _isStreaming = false;
  DateTime? _lastFrameTime;
  int _frameCount = 0;
  double _avgLatency = 0;

  /// Whether a stream is currently active.
  bool get isStreaming => _isStreaming;

  /// Current session ID.
  String? get currentSessionId => _currentSessionId;

  /// Average latency in milliseconds.
  double get averageLatency => _avgLatency;

  /// Frame count since stream started.
  int get frameCount => _frameCount;

  // ===========================================================================
  // Stream Management
  // ===========================================================================

  /// Start a video stream for a robot's camera.
  Future<StreamResponse> startStream({
    required String robotId,
    String? cameraId,
    StreamQuality quality = StreamQuality.medium,
    StreamFormat format = StreamFormat.mjpeg,
  }) async {
    // Stop any existing stream
    await stopStream();

    final uri = Uri.parse(ApiEndpoints.resolve(ApiEndpoints.cameraStreamStart));

    final response = await _httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'robot_id': robotId,
        'camera_id': cameraId,
        'quality': quality.value,
        'format': format.value,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to start stream: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final streamResponse = StreamResponse.fromJson(data);

    _currentSessionId = streamResponse.sessionId;
    _currentCameraId = cameraId;

    // Start consuming the MJPEG stream
    if (format == StreamFormat.mjpeg) {
      await _startMjpegStream(streamResponse);
    }

    return streamResponse;
  }

  /// Stop the current video stream.
  Future<void> stopStream() async {
    _isStreaming = false;
    _statusController.add(CameraStatus.offline);

    await _mjpegSubscription?.cancel();
    _mjpegSubscription = null;

    _streamClient?.close();
    _streamClient = null;

    if (_currentSessionId != null) {
      try {
        final uri = Uri.parse(
          ApiEndpoints.resolve(
            '${ApiEndpoints.cameraStreamStop}/$_currentSessionId/stop',
          ),
        );
        await _httpClient.post(uri);
      } catch (e) {
        // Ignore errors when stopping
      }
    }

    _currentSessionId = null;
    _currentCameraId = null;
    _frameCount = 0;
    _avgLatency = 0;
  }

  Future<void> _startMjpegStream(StreamResponse streamResponse) async {
    _isStreaming = true;
    _statusController.add(CameraStatus.connecting);
    _frameCount = 0;

    try {
      // Create a dedicated client for the stream
      _streamClient = http.Client();

      final streamUrl = ApiEndpoints.mjpegStreamUrl(
        _currentCameraId ?? 'default',
        streamResponse.sessionId,
      );

      final request = http.Request('GET', Uri.parse(streamUrl));
      final streamedResponse = await _streamClient!.send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception(
          'Stream request failed: ${streamedResponse.statusCode}',
        );
      }

      _statusController.add(CameraStatus.streaming);

      // Parse MJPEG multipart stream
      _mjpegSubscription = _parseMjpegStream(streamedResponse.stream).listen(
        (frame) {
          final now = DateTime.now();
          if (_lastFrameTime != null) {
            final latency = now
                .difference(_lastFrameTime!)
                .inMilliseconds
                .toDouble();
            _avgLatency = _avgLatency * 0.9 + latency * 0.1;
            _latencyController.add(_avgLatency);
          }
          _lastFrameTime = now;
          _frameCount++;

          _frameController.add(frame);
        },
        onError: (error) {
          _statusController.add(CameraStatus.error);
          _isStreaming = false;
        },
        onDone: () {
          _statusController.add(CameraStatus.offline);
          _isStreaming = false;
        },
      );
    } catch (e) {
      _statusController.add(CameraStatus.error);
      _isStreaming = false;
      rethrow;
    }
  }

  /// Parse MJPEG multipart stream into individual JPEG frames.
  Stream<Uint8List> _parseMjpegStream(Stream<List<int>> stream) async* {
    final buffer = BytesBuilder();
    final boundary = utf8.encode('--frame');
    final contentType = utf8.encode('Content-Type: image/jpeg');

    await for (final chunk in stream) {
      buffer.add(chunk);
      final data = buffer.toBytes();

      // Look for frame boundaries
      int searchStart = 0;
      while (true) {
        // Find the next boundary
        final boundaryIndex = _indexOf(data, boundary, searchStart);
        if (boundaryIndex == -1) break;

        // Find content-type header
        final headerIndex = _indexOf(
          data,
          contentType,
          boundaryIndex + boundary.length,
        );
        if (headerIndex == -1) break;

        // Find double CRLF (end of headers)
        final doubleCrlf = utf8.encode('\r\n\r\n');
        final headerEndIndex = _indexOf(data, doubleCrlf, headerIndex);
        if (headerEndIndex == -1) break;

        final frameStart = headerEndIndex + doubleCrlf.length;

        // Find next boundary (end of frame)
        final nextBoundaryIndex = _indexOf(data, boundary, frameStart);
        if (nextBoundaryIndex == -1) {
          // Frame not complete yet, wait for more data
          break;
        }

        // Extract frame data (exclude trailing CRLF)
        final frameEnd = nextBoundaryIndex - 2; // Skip \r\n before boundary
        if (frameEnd > frameStart) {
          final frameData = Uint8List.fromList(
            data.sublist(frameStart, frameEnd),
          );

          // Validate it's a JPEG (starts with FFD8)
          if (frameData.length > 2 &&
              frameData[0] == 0xFF &&
              frameData[1] == 0xD8) {
            yield frameData;
          }
        }

        searchStart = nextBoundaryIndex;
      }

      // Keep only unprocessed data in buffer
      if (searchStart > 0) {
        final remaining = data.sublist(searchStart);
        buffer.clear();
        buffer.add(remaining);
      }
    }
  }

  /// Find index of pattern in data starting from offset.
  int _indexOf(List<int> data, List<int> pattern, int start) {
    outer:
    for (int i = start; i <= data.length - pattern.length; i++) {
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  // ===========================================================================
  // Camera Information
  // ===========================================================================

  /// Get cameras for a robot.
  Future<List<CameraInfo>> getCamerasForRobot(String robotId) async {
    final uri = Uri.parse(
      ApiEndpoints.resolve('${ApiEndpoints.cameraSettings}/robot/$robotId'),
    );

    final response = await _httpClient.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data
          .map((e) => CameraInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception('Failed to get cameras: ${response.statusCode}');
  }

  /// Get camera info.
  Future<CameraInfo> getCamera(String cameraId) async {
    final uri = Uri.parse(
      ApiEndpoints.resolve('${ApiEndpoints.cameraSettings}/$cameraId'),
    );

    final response = await _httpClient.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return CameraInfo.fromJson(data);
    }

    throw Exception('Failed to get camera: ${response.statusCode}');
  }

  // ===========================================================================
  // Camera Settings
  // ===========================================================================

  /// Get camera settings.
  Future<CameraSettings> getSettings(String cameraId) async {
    final uri = Uri.parse(
      ApiEndpoints.resolve('${ApiEndpoints.cameraSettings}/$cameraId/settings'),
    );

    final response = await _httpClient.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return CameraSettings.fromJson(data);
    }

    throw Exception('Failed to get settings: ${response.statusCode}');
  }

  /// Update camera settings.
  Future<CameraSettings> updateSettings(
    String cameraId,
    Map<String, dynamic> updates,
  ) async {
    final uri = Uri.parse(
      ApiEndpoints.resolve('${ApiEndpoints.cameraSettings}/$cameraId/settings'),
    );

    final response = await _httpClient.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updates),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return CameraSettings.fromJson(data);
    }

    throw Exception('Failed to update settings: ${response.statusCode}');
  }

  // ===========================================================================
  // Snapshots
  // ===========================================================================

  /// Capture a snapshot.
  Future<Snapshot> captureSnapshot({
    required String robotId,
    String? cameraId,
    StreamQuality quality = StreamQuality.high,
    bool includeMetadata = true,
  }) async {
    final uri = Uri.parse(ApiEndpoints.resolve(ApiEndpoints.cameraSnapshot));

    final response = await _httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'robot_id': robotId,
        'camera_id': cameraId,
        'quality': quality.value,
        'include_metadata': includeMetadata,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Snapshot.fromJson(data);
    }

    throw Exception('Failed to capture snapshot: ${response.statusCode}');
  }

  /// Get snapshots for a robot.
  Future<List<Snapshot>> getSnapshots(String robotId, {int limit = 20}) async {
    final uri = Uri.parse(
      ApiEndpoints.resolve(
        '${ApiEndpoints.cameraSettings}/robot/$robotId/snapshots',
      ),
    ).replace(queryParameters: {'limit': limit.toString()});

    final response = await _httpClient.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data
          .map((e) => Snapshot.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception('Failed to get snapshots: ${response.statusCode}');
  }

  /// Get snapshot image URL.
  String getSnapshotImageUrl(String snapshotId) {
    return ApiEndpoints.resolve(
      '${ApiEndpoints.cameraSettings}/snapshots/$snapshotId/image',
    );
  }

  // ===========================================================================
  // Statistics
  // ===========================================================================

  /// Get camera stats.
  Future<CameraStats> getStats(String cameraId) async {
    final uri = Uri.parse(
      ApiEndpoints.resolve('${ApiEndpoints.cameraSettings}/$cameraId/stats'),
    );

    final response = await _httpClient.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return CameraStats.fromJson(data);
    }

    throw Exception('Failed to get stats: ${response.statusCode}');
  }

  /// Dispose resources.
  void dispose() {
    stopStream();
    _frameController.close();
    _statusController.close();
    _latencyController.close();
  }
}
