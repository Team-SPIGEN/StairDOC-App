import 'package:flutter/material.dart';

import '../../utils/ui_constants.dart';

/// Voice control interface for robot commands.
class VoiceControlScreen extends StatefulWidget {
  const VoiceControlScreen({super.key});

  @override
  State<VoiceControlScreen> createState() => _VoiceControlScreenState();
}

class _VoiceControlScreenState extends State<VoiceControlScreen>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<_VoiceCommand> _recentCommands = [
    _VoiceCommand(
      command: 'Go to Floor 3',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      success: true,
    ),
    _VoiceCommand(
      command: 'Unlock container',
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      success: true,
    ),
    _VoiceCommand(
      command: 'Return to base',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      success: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Control'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isListening ? _pulseAnimation.value : 1.0,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isListening
                                  ? colorScheme.primary
                                  : colorScheme.primary.withValues(alpha: 0.12),
                              boxShadow: _isListening
                                  ? [
                                      BoxShadow(
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 30,
                                        spreadRadius: 10,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: IconButton(
                              onPressed: _toggleListening,
                              icon: Icon(
                                _isListening
                                    ? Icons.mic
                                    : Icons.mic_none_rounded,
                                size: 56,
                                color: _isListening
                                    ? colorScheme.onPrimary
                                    : colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: Insets.lg),
                    Text(
                      _isListening ? 'Listening...' : 'Tap to speak',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      _isListening
                          ? 'Say a command like "Go to Floor 2"'
                          : 'Press the microphone to start',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Available commands hint
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Commands',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _showAvailableCommands(context);
                        },
                        child: const Text('Available Commands'),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.sm),
                  ..._recentCommands.map(
                    (cmd) => _CommandHistoryItem(command: cmd),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvailableCommands(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Voice Commands',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Insets.md),
            _CommandExample(command: 'Go to Floor [number]'),
            _CommandExample(command: 'Unlock container'),
            _CommandExample(command: 'Lock container'),
            _CommandExample(command: 'Return to base'),
            _CommandExample(command: 'Emergency stop'),
            _CommandExample(command: 'Start delivery'),
            _CommandExample(command: 'Status report'),
            const SizedBox(height: Insets.md),
          ],
        ),
      ),
    );
  }
}

class _VoiceCommand {
  const _VoiceCommand({
    required this.command,
    required this.timestamp,
    required this.success,
  });

  final String command;
  final DateTime timestamp;
  final bool success;
}

class _CommandHistoryItem extends StatelessWidget {
  const _CommandHistoryItem({required this.command});

  final _VoiceCommand command;

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        children: [
          Icon(
            command.success ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 18,
            color: command.success ? Colors.green : Colors.red,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              '"${command.command}"',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            _formatTime(command.timestamp),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandExample extends StatelessWidget {
  const _CommandExample({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.xs),
      child: Row(
        children: [
          Icon(
            Icons.arrow_right_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          Text('"$command"', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
