/// Live camera feed screen for viewing robot camera.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/camera_cubit.dart';
import '../models/camera.dart';
import '../services/camera_service.dart';
import '../widgets/camera_widgets.dart';

/// Full screen camera viewing experience.
class CameraScreen extends StatelessWidget {
  const CameraScreen({
    super.key,
    required this.robotId,
    this.cameraId,
    this.autoStart = true,
  });

  final String robotId;
  final String? cameraId;
  final bool autoStart;

  static Route<void> route({
    required String robotId,
    String? cameraId,
    bool autoStart = true,
  }) {
    return MaterialPageRoute(
      builder: (context) => CameraScreen(
        robotId: robotId,
        cameraId: cameraId,
        autoStart: autoStart,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CameraCubit(cameraService: CameraService()),
      child: _CameraScreenContent(
        robotId: robotId,
        cameraId: cameraId,
        autoStart: autoStart,
      ),
    );
  }
}

class _CameraScreenContent extends StatefulWidget {
  const _CameraScreenContent({
    required this.robotId,
    this.cameraId,
    required this.autoStart,
  });

  final String robotId;
  final String? cameraId;
  final bool autoStart;

  @override
  State<_CameraScreenContent> createState() => _CameraScreenContentState();
}

class _CameraScreenContentState extends State<_CameraScreenContent> {
  bool _isFullscreen = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CameraCubit>().startStream(
          robotId: widget.robotId,
          cameraId: widget.cameraId,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullscreen
          ? null
          : AppBar(
              title: const Text('Live Camera'),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              actions: [
                BlocBuilder<CameraCubit, CameraState>(
                  builder: (context, state) {
                    return Row(
                      children: [
                        if (state.isStreaming)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: LatencyIndicator(latency: state.latency),
                          ),
                        IconButton(
                          icon: const Icon(Icons.fullscreen),
                          onPressed: () => _toggleFullscreen(true),
                          tooltip: 'Fullscreen',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video stream
            const Center(
              child: CameraStreamView(
                showLatency: false, // Shown in app bar instead
                showFrameCount: false,
              ),
            ),

            // Controls overlay
            if (_showControls || !_isFullscreen) ...[
              // Bottom controls
              _buildBottomControls(),

              // Quality indicator
              _buildQualityIndicator(),

              // Fullscreen exit button
              if (_isFullscreen) _buildFullscreenExitButton(),
            ],

            // Snapshot feedback
            _buildSnapshotFeedback(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            24,
            16,
            _isFullscreen ? 24 : MediaQuery.of(context).padding.bottom + 16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
            ),
          ),
          child: CameraStreamControls(
            robotId: widget.robotId,
            cameraId: widget.cameraId,
            showQualitySelector: true,
            showSnapshotButton: true,
            onSnapshotTaken: _onSnapshotTaken,
          ),
        ),
      ),
    );
  }

  Widget _buildQualityIndicator() {
    return Positioned(
      top: _isFullscreen ? MediaQuery.of(context).padding.top + 16 : 16,
      left: 16,
      child: BlocBuilder<CameraCubit, CameraState>(
        builder: (context, state) {
          if (!state.isStreaming) return const SizedBox.shrink();

          return AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(state.quality.icon, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    state.quality.label,
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
        },
      ),
    );
  }

  Widget _buildFullscreenExitButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IconButton(
          onPressed: () => _toggleFullscreen(false),
          icon: const Icon(Icons.fullscreen_exit),
          color: Colors.white,
          style: IconButton.styleFrom(backgroundColor: Colors.black54),
        ),
      ),
    );
  }

  Widget _buildSnapshotFeedback() {
    return BlocBuilder<CameraCubit, CameraState>(
      buildWhen: (previous, current) =>
          previous.lastSnapshot != current.lastSnapshot,
      builder: (context, state) {
        if (state.lastSnapshot == null) return const SizedBox.shrink();

        return Positioned(
          bottom: 100,
          right: 16,
          child: _SnapshotPreviewPopup(snapshot: state.lastSnapshot!),
        );
      },
    );
  }

  void _toggleControls() {
    if (_isFullscreen) {
      setState(() {
        _showControls = !_showControls;
      });
    }
  }

  void _toggleFullscreen(bool fullscreen) {
    setState(() {
      _isFullscreen = fullscreen;
      _showControls = true;
    });

    if (fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  void _onSnapshotTaken() {
    // Show feedback animation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Snapshot captured'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    // Reset system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }
}

class _SnapshotPreviewPopup extends StatefulWidget {
  const _SnapshotPreviewPopup({required this.snapshot});

  final Snapshot snapshot;

  @override
  State<_SnapshotPreviewPopup> createState() => _SnapshotPreviewPopupState();
}

class _SnapshotPreviewPopupState extends State<_SnapshotPreviewPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 20,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(opacity: _fadeAnimation.value, child: child),
        );
      },
      child: SnapshotPreview(snapshot: widget.snapshot, width: 100, height: 75),
    );
  }
}

/// Compact camera preview widget for dashboard.
class CameraPreviewCard extends StatelessWidget {
  const CameraPreviewCard({
    super.key,
    required this.robotId,
    this.cameraId,
    this.onExpand,
  });

  final String robotId;
  final String? cameraId;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CameraCubit(cameraService: CameraService()),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.videocam, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Live Camera',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  BlocBuilder<CameraCubit, CameraState>(
                    builder: (context, state) {
                      return CameraStatusIndicator(
                        status: state.cameraStatus,
                        showLabel: false,
                      );
                    },
                  ),
                ],
              ),
            ),

            // Preview
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const CameraStreamView(
                    fit: BoxFit.cover,
                    showLatency: true,
                    borderRadius: BorderRadius.zero,
                  ),

                  // Expand button
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: IconButton.filled(
                      onPressed:
                          onExpand ??
                          () {
                            Navigator.of(context).push(
                              CameraScreen.route(
                                robotId: robotId,
                                cameraId: cameraId,
                              ),
                            );
                          },
                      icon: const Icon(Icons.open_in_full, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(36, 36),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Controls
            Padding(
              padding: const EdgeInsets.all(8),
              child: Builder(
                builder: (context) {
                  return CameraStreamControls(
                    robotId: robotId,
                    cameraId: cameraId,
                    showQualitySelector: false,
                    showSnapshotButton: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Camera settings sheet.
class CameraSettingsSheet extends StatefulWidget {
  const CameraSettingsSheet({
    super.key,
    required this.cameraId,
    required this.initialSettings,
  });

  final String cameraId;
  final CameraSettings initialSettings;

  static Future<CameraSettings?> show(
    BuildContext context, {
    required String cameraId,
    required CameraSettings initialSettings,
  }) {
    return showModalBottomSheet<CameraSettings>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CameraSettingsSheet(
        cameraId: cameraId,
        initialSettings: initialSettings,
      ),
    );
  }

  @override
  State<CameraSettingsSheet> createState() => _CameraSettingsSheetState();
}

class _CameraSettingsSheetState extends State<CameraSettingsSheet> {
  late double _brightness;
  late double _contrast;
  late double _saturation;
  late bool _nightVision;
  late bool _autoFocus;

  @override
  void initState() {
    super.initState();
    final s = widget.initialSettings;
    _brightness = s.brightness / 100.0;
    _contrast = s.contrast / 100.0;
    _saturation = s.saturation / 100.0;
    _nightVision = s.nightVision;
    _autoFocus = s.autoFocus;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  const Text(
                    'Camera Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _resetDefaults,
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Brightness
              _buildSlider(
                label: 'Brightness',
                value: _brightness,
                icon: Icons.brightness_6,
                onChanged: (v) => setState(() => _brightness = v),
              ),

              // Contrast
              _buildSlider(
                label: 'Contrast',
                value: _contrast,
                icon: Icons.contrast,
                onChanged: (v) => setState(() => _contrast = v),
              ),

              // Saturation
              _buildSlider(
                label: 'Saturation',
                value: _saturation,
                icon: Icons.palette,
                onChanged: (v) => setState(() => _saturation = v),
              ),

              const Divider(height: 32),

              // Toggles
              SwitchListTile(
                title: const Text('Night Vision'),
                subtitle: const Text('Enhanced low-light visibility'),
                secondary: const Icon(Icons.nightlight_round),
                value: _nightVision,
                onChanged: (v) => setState(() => _nightVision = v),
              ),

              SwitchListTile(
                title: const Text('Auto Focus'),
                subtitle: const Text('Automatic focus adjustment'),
                secondary: const Icon(Icons.center_focus_strong),
                value: _autoFocus,
                onChanged: (v) => setState(() => _autoFocus = v),
              ),

              const SizedBox(height: 24),

              // Apply button
              FilledButton(
                onPressed: _applySettings,
                child: const Text('Apply Settings'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required IconData icon,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(label),
              const Spacer(),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Slider(value: value, min: 0, max: 1, onChanged: onChanged),
        ],
      ),
    );
  }

  void _resetDefaults() {
    setState(() {
      _brightness = 0.5;
      _contrast = 0.5;
      _saturation = 0.5;
      _nightVision = false;
      _autoFocus = true;
    });
  }

  void _applySettings() {
    final settings = CameraSettings(
      brightness: (_brightness * 100).round(),
      contrast: (_contrast * 100).round(),
      saturation: (_saturation * 100).round(),
      nightVision: _nightVision,
      autoFocus: _autoFocus,
      quality: widget.initialSettings.quality,
    );
    Navigator.of(context).pop(settings);
  }
}
