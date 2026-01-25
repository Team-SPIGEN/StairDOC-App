/// Camera stream view widget for displaying live video feed.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/camera_cubit.dart';
import '../models/camera.dart';

/// Widget for displaying the camera stream.
class CameraStreamView extends StatelessWidget {
  const CameraStreamView({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.loadingWidget,
    this.errorWidget,
    this.placeholderWidget,
    this.showLatency = true,
    this.showFrameCount = false,
    this.borderRadius = BorderRadius.zero,
  });

  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? placeholderWidget;
  final bool showLatency;
  final bool showFrameCount;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraCubit, CameraState>(
      builder: (context, state) {
        return ClipRRect(
          borderRadius: borderRadius,
          child: Container(
            width: width,
            height: height,
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildContent(context, state),
                if (showLatency && state.isStreaming)
                  _buildLatencyOverlay(state),
                if (showFrameCount && state.isStreaming)
                  _buildFrameCountOverlay(state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, CameraState state) {
    switch (state.status) {
      case CameraStateStatus.initial:
        return placeholderWidget ?? _buildPlaceholder(context);

      case CameraStateStatus.connecting:
        return loadingWidget ?? _buildLoading(context);

      case CameraStateStatus.streaming:
        if (state.currentFrame != null) {
          return _buildFrame(state.currentFrame!);
        }
        return loadingWidget ?? _buildLoading(context);

      case CameraStateStatus.paused:
        if (state.currentFrame != null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _buildFrame(state.currentFrame!),
              Container(
                color: Colors.black45,
                child: const Center(
                  child: Icon(
                    Icons.pause_circle_outline,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
            ],
          );
        }
        return _buildPlaceholder(context);

      case CameraStateStatus.error:
        return errorWidget ?? _buildError(context, state.errorMessage);
    }
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 64, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          Text(
            'Camera not connected',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'Connecting to camera...',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildFrame(Uint8List frame) {
    return Image.memory(
      frame,
      fit: fit,
      gaplessPlayback: true, // Prevents flickering between frames
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
        );
      },
    );
  }

  Widget _buildError(BuildContext context, String? message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Stream Error',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.red.shade300),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade400),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLatencyOverlay(CameraState state) {
    final latency = state.latency;
    final isGood = latency > 0 && latency < 500;

    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isGood ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              latency > 0 ? '${latency.toStringAsFixed(0)}ms' : '--',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrameCountOverlay(CameraState state) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${state.frameCount} frames',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}

/// Controls for the camera stream.
class CameraStreamControls extends StatelessWidget {
  const CameraStreamControls({
    super.key,
    required this.robotId,
    this.cameraId,
    this.showQualitySelector = true,
    this.showSnapshotButton = true,
    this.onSnapshotTaken,
  });

  final String robotId;
  final String? cameraId;
  final bool showQualitySelector;
  final bool showSnapshotButton;
  final VoidCallback? onSnapshotTaken;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraCubit, CameraState>(
      builder: (context, state) {
        final isStreaming = state.isStreaming;
        final isConnecting = state.isConnecting;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Play/Stop button
            IconButton.filled(
              onPressed: isConnecting
                  ? null
                  : () {
                      if (isStreaming) {
                        context.read<CameraCubit>().stopStream();
                      } else {
                        context.read<CameraCubit>().startStream(
                          robotId: robotId,
                          cameraId: cameraId,
                        );
                      }
                    },
              icon: isConnecting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(isStreaming ? Icons.stop : Icons.play_arrow),
              tooltip: isStreaming ? 'Stop stream' : 'Start stream',
            ),

            if (showQualitySelector) ...[
              const SizedBox(width: 16),
              _QualitySelector(
                currentQuality: state.quality,
                enabled: !isConnecting,
                onChanged: (quality) {
                  context.read<CameraCubit>().changeQuality(quality);
                },
              ),
            ],

            if (showSnapshotButton) ...[
              const SizedBox(width: 16),
              IconButton.filled(
                onPressed: isStreaming
                    ? () async {
                        await context.read<CameraCubit>().captureSnapshot();
                        onSnapshotTaken?.call();
                      }
                    : null,
                icon: const Icon(Icons.camera_alt),
                tooltip: 'Capture snapshot',
              ),
            ],
          ],
        );
      },
    );
  }
}

class _QualitySelector extends StatelessWidget {
  const _QualitySelector({
    required this.currentQuality,
    required this.enabled,
    required this.onChanged,
  });

  final StreamQuality currentQuality;
  final bool enabled;
  final ValueChanged<StreamQuality> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<StreamQuality>(
      enabled: enabled,
      initialValue: currentQuality,
      onSelected: onChanged,
      tooltip: 'Stream quality',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.high_quality, size: 20),
            const SizedBox(width: 4),
            Text(
              currentQuality.label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        return StreamQuality.values.map((quality) {
          return PopupMenuItem<StreamQuality>(
            value: quality,
            child: Row(
              children: [
                Icon(quality.icon, size: 20),
                const SizedBox(width: 8),
                Text(quality.label),
                const Spacer(),
                Text(
                  quality.description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}

/// Snapshot preview widget.
class SnapshotPreview extends StatelessWidget {
  const SnapshotPreview({
    super.key,
    required this.snapshot,
    this.onTap,
    this.showTimestamp = true,
    this.width = 120,
    this.height = 90,
  });

  final Snapshot snapshot;
  final VoidCallback? onTap;
  final bool showTimestamp;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade700),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                snapshot.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) {
                  return const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
              ),
              if (showTimestamp)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    color: Colors.black54,
                    child: Text(
                      _formatTime(snapshot.timestamp),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Camera status indicator.
class CameraStatusIndicator extends StatelessWidget {
  const CameraStatusIndicator({
    super.key,
    required this.status,
    this.size = 12,
    this.showLabel = true,
  });

  final CameraStatus status;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: status.color,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(status.label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// Latency indicator widget.
class LatencyIndicator extends StatelessWidget {
  const LatencyIndicator({
    super.key,
    required this.latency,
    this.targetLatency = 500,
  });

  final double latency;
  final double targetLatency;

  @override
  Widget build(BuildContext context) {
    final isGood = latency > 0 && latency < targetLatency;
    final color = isGood
        ? Colors.green
        : latency < targetLatency * 2
        ? Colors.orange
        : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGood ? Icons.signal_cellular_4_bar : Icons.signal_cellular_alt,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            latency > 0 ? '${latency.toStringAsFixed(0)}ms' : 'N/A',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
