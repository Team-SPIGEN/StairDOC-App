/// Voice feedback overlay showing recognition status.
///
/// Displays:
/// - Real-time transcript
/// - Command result and response
/// - Error messages
/// - Available commands help
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/voice_command.dart';
import '../../providers/voice/voice_cubit.dart';
import '../../providers/voice/voice_state.dart';
import '../../utils/ui_constants.dart';

/// Modal overlay showing voice command feedback.
class VoiceFeedbackOverlay extends StatelessWidget {
  const VoiceFeedbackOverlay({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VoiceFeedbackOverlay(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: BlocBuilder<VoiceCubit, VoiceState>(
            builder: (context, state) {
              return Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Row(
                      children: [
                        _StatusIndicator(state: state),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: Text(
                            _getStatusText(state),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (state.isListening || state.isSpeaking)
                          IconButton(
                            icon: const Icon(Icons.stop_rounded),
                            onPressed: () {
                              if (state.isListening) {
                                context.read<VoiceCubit>().cancelListening();
                              } else {
                                context.read<VoiceCubit>().stopSpeaking();
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(Insets.md),
                      children: [
                        // Current transcript
                        if (state.currentTranscript.isNotEmpty)
                          _TranscriptCard(transcript: state.currentTranscript),

                        // Last result
                        if (state.lastResult != null) ...[
                          const SizedBox(height: Insets.md),
                          _ResultCard(result: state.lastResult!),
                        ],

                        // Error
                        if (state.hasError) ...[
                          const SizedBox(height: Insets.md),
                          _ErrorCard(error: state.errorMessage!),
                        ],

                        // Help section
                        const SizedBox(height: Insets.lg),
                        _HelpSection(capabilities: state.capabilities),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _getStatusText(VoiceState state) {
    if (state.isListening) return 'Listening...';
    if (state.isProcessing) return 'Processing...';
    if (state.isSpeaking) return 'Speaking...';
    if (state.hasError) return 'Error';
    return 'Voice Commands';
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.state});

  final VoiceState state;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _getIndicatorStyle();

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  (Color, IconData) _getIndicatorStyle() {
    if (state.isListening) {
      return (Colors.red, Icons.mic_rounded);
    }
    if (state.isProcessing) {
      return (Colors.orange, Icons.auto_awesome_rounded);
    }
    if (state.isSpeaking) {
      return (Colors.blue, Icons.volume_up_rounded);
    }
    if (state.hasError) {
      return (Colors.red, Icons.error_outline_rounded);
    }
    return (Colors.green, Icons.mic_none_rounded);
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.transcript});

  final String transcript;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: CornerRadius.card,
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Transcript',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            transcript,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
            ),
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
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: CornerRadius.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Intent badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSuccess
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 14,
                      color: resultColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatIntent(result.intent),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: resultColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _ConfidenceBadge(
                confidence: result.confidence,
                level: result.confidenceLevel,
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          // Response text
          Text(result.responseText, style: theme.textTheme.bodyMedium),
          // Parameters
          if (result.parameters.isNotEmpty) ...[
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: 8,
              children: result.parameters.map((p) {
                return Chip(
                  label: Text('${p.name}: ${p.value}'),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          // Error message
          if (result.errorMessage != null) ...[
            const SizedBox(height: Insets.sm),
            Text(
              result.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
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
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence, required this.level});

  final double confidence;
  final CommandConfidence level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = switch (level) {
      CommandConfidence.high => Colors.green,
      CommandConfidence.medium => Colors.orange,
      CommandConfidence.low => Colors.red,
      CommandConfidence.uncertain => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${(confidence * 100).toInt()}%',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
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
          TextButton(
            onPressed: () => context.read<VoiceCubit>().clearError(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({this.capabilities});

  final VoiceCapabilities? capabilities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Default commands if no capabilities loaded
    final commands =
        capabilities?.supportedCommands ??
        [
          const SupportedCommand(
            intent: VoiceCommandIntent.goToFloor,
            description: 'Navigate to a floor',
            examplePhrases: ['Go to floor 3', 'Take me to level 2'],
          ),
          const SupportedCommand(
            intent: VoiceCommandIntent.lockContainer,
            description: 'Lock the container',
            examplePhrases: ['Lock container', 'Secure the box'],
          ),
          const SupportedCommand(
            intent: VoiceCommandIntent.checkBattery,
            description: 'Check battery level',
            examplePhrases: ['Battery status', 'How much battery'],
          ),
          const SupportedCommand(
            intent: VoiceCommandIntent.emergencyStop,
            description: 'Emergency stop',
            examplePhrases: ['Emergency stop', 'Stop immediately'],
          ),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.help_outline_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Try saying...',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        ...commands
            .take(6)
            .map(
              (cmd) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CommandExample(command: cmd),
              ),
            ),
      ],
    );
  }
}

class _CommandExample extends StatelessWidget {
  const _CommandExample({required this.command});

  final SupportedCommand command;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(Insets.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getIconForIntent(command.intent),
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  command.examplePhrases.isNotEmpty
                      ? '"${command.examplePhrases.first}"'
                      : command.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  command.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForIntent(VoiceCommandIntent intent) {
    return switch (intent) {
      VoiceCommandIntent.goToFloor => Icons.stairs_rounded,
      VoiceCommandIntent.goToZone => Icons.location_on_rounded,
      VoiceCommandIntent.goHome => Icons.home_rounded,
      VoiceCommandIntent.stop => Icons.stop_rounded,
      VoiceCommandIntent.lockContainer => Icons.lock_rounded,
      VoiceCommandIntent.unlockContainer => Icons.lock_open_rounded,
      VoiceCommandIntent.openContainer => Icons.open_in_browser_rounded,
      VoiceCommandIntent.startDelivery => Icons.local_shipping_rounded,
      VoiceCommandIntent.cancelDelivery => Icons.cancel_rounded,
      VoiceCommandIntent.checkDeliveryStatus => Icons.track_changes_rounded,
      VoiceCommandIntent.checkBattery => Icons.battery_std_rounded,
      VoiceCommandIntent.checkLocation => Icons.my_location_rounded,
      VoiceCommandIntent.checkStatus => Icons.info_outline_rounded,
      VoiceCommandIntent.emergencyStop => Icons.warning_rounded,
      VoiceCommandIntent.help => Icons.help_rounded,
      VoiceCommandIntent.unknown => Icons.question_mark_rounded,
    };
  }
}
