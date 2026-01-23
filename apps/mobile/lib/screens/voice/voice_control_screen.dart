/// Voice control screen for managing voice commands.
///
/// Provides:
/// - Large microphone button for voice input
/// - Real-time transcript display
/// - Command history and results
/// - Available commands reference
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/voice_command.dart';
import '../../providers/voice/voice_cubit.dart';
import '../../providers/voice/voice_state.dart';
import '../../utils/ui_constants.dart';
import '../../widgets/voice/voice_command_button.dart';
import '../../widgets/voice/voice_feedback_overlay.dart';

/// Screen for voice command interaction.
class VoiceControlScreen extends StatelessWidget {
  const VoiceControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => VoiceCubit()..initialize(),
      child: const _VoiceControlView(),
    );
  }
}

class _VoiceControlView extends StatelessWidget {
  const _VoiceControlView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Control'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          BlocBuilder<VoiceCubit, VoiceState>(
            builder: (context, state) {
              return IconButton(
                icon: Icon(
                  state.speakFeedback
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                ),
                tooltip: state.speakFeedback
                    ? 'Voice feedback on'
                    : 'Voice feedback off',
                onPressed: () {
                  context.read<VoiceCubit>().setSpeakFeedback(
                    !state.speakFeedback,
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Help',
            onPressed: () => VoiceFeedbackOverlay.show(context),
          ),
        ],
      ),
      body: BlocBuilder<VoiceCubit, VoiceState>(
        builder: (context, state) {
          return Column(
            children: [
              // Status header
              _StatusHeader(state: state),

              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Column(
                    children: [
                      // Transcript display
                      if (state.currentTranscript.isNotEmpty ||
                          state.isListening)
                        _TranscriptDisplay(
                          transcript: state.currentTranscript,
                          isListening: state.isListening,
                        ),

                      // Last result
                      if (state.lastResult != null) ...[
                        const SizedBox(height: Insets.lg),
                        _ResultCard(result: state.lastResult!),
                      ],

                      // Error display
                      if (state.hasError) ...[
                        const SizedBox(height: Insets.md),
                        _ErrorDisplay(
                          error: state.errorMessage!,
                          onDismiss: () =>
                              context.read<VoiceCubit>().clearError(),
                        ),
                      ],

                      // Quick commands
                      const SizedBox(height: Insets.lg),
                      _QuickCommandsSection(state: state),
                    ],
                  ),
                ),
              ),

              // Bottom action area
              _BottomActionArea(state: state),
            ],
          );
        },
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.state});

  final VoiceState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (statusText, statusColor, statusIcon) = _getStatusInfo();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: statusColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Insets.sm),
          Icon(statusIcon, size: 18, color: statusColor),
          const SizedBox(width: Insets.xs),
          Text(
            statusText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (!state.isInitialized)
            TextButton(
              onPressed: () => context.read<VoiceCubit>().initialize(),
              child: const Text('Initialize'),
            ),
        ],
      ),
    );
  }

  (String, Color, IconData) _getStatusInfo() {
    if (!state.isInitialized) {
      return ('Not initialized', Colors.grey, Icons.mic_off_rounded);
    }
    if (state.hasError) {
      return ('Error', Colors.red, Icons.error_outline_rounded);
    }
    if (state.isListening) {
      return ('Listening...', Colors.red, Icons.mic_rounded);
    }
    if (state.isProcessing) {
      return ('Processing...', Colors.orange, Icons.auto_awesome_rounded);
    }
    if (state.isSpeaking) {
      return ('Speaking...', Colors.blue, Icons.volume_up_rounded);
    }
    return ('Ready', Colors.green, Icons.mic_none_rounded);
  }
}

class _TranscriptDisplay extends StatelessWidget {
  const _TranscriptDisplay({
    required this.transcript,
    required this.isListening,
  });

  final String transcript;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: CornerRadius.card,
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          if (isListening && transcript.isEmpty)
            Column(
              children: [
                Icon(Icons.mic_rounded, size: 48, color: colorScheme.primary),
                const SizedBox(height: Insets.sm),
                Text(
                  'Speak now...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ],
            )
          else
            Text(
              transcript.isEmpty ? 'Tap the microphone to start' : transcript,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontStyle: transcript.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
                color: transcript.isEmpty
                    ? colorScheme.onSurface.withValues(alpha: 0.5)
                    : colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final VoiceCommandResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isSuccess = result.success;
    final resultColor = isSuccess ? Colors.green : colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: CornerRadius.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with intent and confidence
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSuccess
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      size: 16,
                      color: resultColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatIntent(result.intent),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: resultColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getConfidenceColor(
                    result.confidenceLevel,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(result.confidence * 100).toInt()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _getConfidenceColor(result.confidenceLevel),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          // Response
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Insets.sm),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    result.responseText,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          // Original transcript
          const SizedBox(height: Insets.sm),
          Text(
            '"${result.originalTranscript}"',
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  String _formatIntent(VoiceCommandIntent intent) {
    return intent.value
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  Color _getConfidenceColor(CommandConfidence level) {
    return switch (level) {
      CommandConfidence.high => Colors.green,
      CommandConfidence.medium => Colors.orange,
      CommandConfidence.low => Colors.red,
      CommandConfidence.uncertain => Colors.grey,
    };
  }
}

class _ErrorDisplay extends StatelessWidget {
  const _ErrorDisplay({required this.error, required this.onDismiss});

  final String error;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: CornerRadius.card,
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onDismiss,
            color: colorScheme.error,
          ),
        ],
      ),
    );
  }
}

class _QuickCommandsSection extends StatelessWidget {
  const _QuickCommandsSection({required this.state});

  final VoiceState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final quickCommands = [
      ('Go to floor 1', VoiceCommandIntent.goToFloor, Icons.stairs_rounded),
      (
        'Check battery',
        VoiceCommandIntent.checkBattery,
        Icons.battery_std_rounded,
      ),
      ('Lock container', VoiceCommandIntent.lockContainer, Icons.lock_rounded),
      (
        'Emergency stop',
        VoiceCommandIntent.emergencyStop,
        Icons.warning_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Commands',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Insets.sm),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.sm,
          children: quickCommands.map((cmd) {
            final (text, intent, icon) = cmd;
            final isEmergency = intent == VoiceCommandIntent.emergencyStop;

            return ActionChip(
              avatar: Icon(
                icon,
                size: 18,
                color: isEmergency ? colorScheme.error : colorScheme.primary,
              ),
              label: Text(text),
              backgroundColor: isEmergency
                  ? colorScheme.errorContainer.withValues(alpha: 0.3)
                  : null,
              onPressed: state.isBusy
                  ? null
                  : () => context.read<VoiceCubit>().processText(text),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BottomActionArea extends StatelessWidget {
  const _BottomActionArea({required this.state});

  final VoiceState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main microphone button
            VoiceCommandButton(
              size: 72,
              onResult: (result) {
                // Result is handled by the BLoC
              },
            ),
            const SizedBox(height: Insets.sm),
            Text(
              state.isListening
                  ? 'Tap to stop'
                  : state.isProcessing
                  ? 'Processing...'
                  : 'Tap to speak',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
