/// Voice command button with listening animation.
///
/// A floating action button that:
/// - Pulses when listening
/// - Shows microphone icon states
/// - Provides haptic feedback
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../providers/voice/voice_cubit.dart';
import '../../providers/voice/voice_state.dart';

/// Floating voice command button with animated states.
class VoiceCommandButton extends StatefulWidget {
  const VoiceCommandButton({super.key, this.size = 56.0, this.onResult});

  /// Button size.
  final double size;

  /// Callback when a command result is received.
  final void Function(dynamic result)? onResult;

  @override
  State<VoiceCommandButton> createState() => _VoiceCommandButtonState();
}

class _VoiceCommandButtonState extends State<VoiceCommandButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updateAnimation(VoiceState state) {
    if (state.isListening) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VoiceCubit, VoiceState>(
      listener: (context, state) {
        _updateAnimation(state);

        // Notify on result
        if (state.lastResult != null && widget.onResult != null) {
          widget.onResult!(state.lastResult);
        }
      },
      builder: (context, state) {
        final colorScheme = Theme.of(context).colorScheme;

        final (buttonColor, iconColor, icon) = _getButtonStyle(
          state,
          colorScheme,
        );

        return GestureDetector(
          onTap: () => _onTap(context, state),
          onLongPress: () => _onLongPress(context, state),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final scale = state.isListening ? _pulseAnimation.value : 1.0;

              return Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: buttonColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: buttonColor.withValues(alpha: 0.4),
                        blurRadius: state.isListening ? 16 : 8,
                        spreadRadius: state.isListening ? 2 : 0,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulse rings when listening
                      if (state.isListening) ...[
                        _PulseRing(
                          size: widget.size,
                          color: buttonColor,
                          delay: 0,
                        ),
                        _PulseRing(
                          size: widget.size,
                          color: buttonColor,
                          delay: 300,
                        ),
                      ],
                      // Main icon
                      Icon(icon, color: iconColor, size: widget.size * 0.5),
                      // Processing indicator
                      if (state.isProcessing)
                        SizedBox(
                          width: widget.size * 0.8,
                          height: widget.size * 0.8,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: iconColor,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  (Color, Color, IconData) _getButtonStyle(
    VoiceState state,
    ColorScheme colorScheme,
  ) {
    if (state.hasError) {
      return (colorScheme.error, colorScheme.onError, Icons.mic_off_rounded);
    }

    if (state.isListening) {
      return (Colors.red, Colors.white, Icons.mic_rounded);
    }

    if (state.isProcessing) {
      return (
        colorScheme.tertiary,
        colorScheme.onTertiary,
        Icons.auto_awesome_rounded,
      );
    }

    if (state.isSpeaking) {
      return (
        colorScheme.secondary,
        colorScheme.onSecondary,
        Icons.volume_up_rounded,
      );
    }

    return (colorScheme.primary, colorScheme.onPrimary, Icons.mic_none_rounded);
  }

  Future<void> _onTap(BuildContext context, VoiceState state) async {
    // Get cubit before async gap
    final cubit = context.read<VoiceCubit>();

    // Haptic feedback
    await HapticFeedback.mediumImpact();

    if (!state.isInitialized) {
      await cubit.initialize();
      return;
    }

    if (state.isSpeaking) {
      await cubit.stopSpeaking();
      return;
    }

    if (state.hasError) {
      cubit.clearError();
      await cubit.initialize();
      return;
    }

    await cubit.toggleListening();
  }

  Future<void> _onLongPress(BuildContext context, VoiceState state) async {
    // Get cubit before async gap
    final cubit = context.read<VoiceCubit>();

    await HapticFeedback.heavyImpact();

    if (state.isListening) {
      await cubit.cancelListening();
    }
  }
}

/// Animated pulse ring for listening state.
class _PulseRing extends StatefulWidget {
  const _PulseRing({required this.size, required this.color, this.delay = 0});

  final double size;
  final Color color;
  final int delay;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat();
      }
    });
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
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.color.withValues(alpha: _opacityAnimation.value),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Compact voice button for inline use.
class VoiceCommandChip extends StatelessWidget {
  const VoiceCommandChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoiceCubit, VoiceState>(
      builder: (context, state) {
        final colorScheme = Theme.of(context).colorScheme;

        return ActionChip(
          avatar: Icon(
            state.isListening
                ? Icons.mic_rounded
                : state.isProcessing
                ? Icons.auto_awesome_rounded
                : Icons.mic_none_rounded,
            size: 18,
            color: state.isListening ? Colors.red : colorScheme.primary,
          ),
          label: Text(
            state.isListening
                ? 'Listening...'
                : state.isProcessing
                ? 'Processing...'
                : 'Voice',
          ),
          onPressed: () => context.read<VoiceCubit>().toggleListening(),
        );
      },
    );
  }
}
