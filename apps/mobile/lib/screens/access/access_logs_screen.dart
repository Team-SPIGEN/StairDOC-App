import 'package:flutter/material.dart';

import '../../utils/ui_constants.dart';

/// Displays access log entries for container lock/unlock events.
class AccessLogsScreen extends StatelessWidget {
  const AccessLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = [
      _AccessLogEntry(
        user: 'John Doe',
        action: AccessAction.unlock,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        location: 'Floor 2 - Office 201',
      ),
      _AccessLogEntry(
        user: 'Jane Smith',
        action: AccessAction.lock,
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        location: 'Floor 3 - Office 305',
      ),
      _AccessLogEntry(
        user: 'John Doe',
        action: AccessAction.lock,
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        location: 'Floor 2 - Office 201',
      ),
      _AccessLogEntry(
        user: 'Admin',
        action: AccessAction.unlock,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        location: 'Floor 1 - Reception',
      ),
      _AccessLogEntry(
        user: 'System',
        action: AccessAction.autoLock,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        location: 'Floor 1 - Reception',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Logs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Filter options coming soon!')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(Insets.lg),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final isFirst = index == 0;
            final isLast = index == logs.length - 1;

            return _AccessLogCard(log: log, isFirst: isFirst, isLast: isLast);
          },
        ),
      ),
    );
  }
}

enum AccessAction { lock, unlock, autoLock }

class _AccessLogEntry {
  const _AccessLogEntry({
    required this.user,
    required this.action,
    required this.timestamp,
    required this.location,
  });

  final String user;
  final AccessAction action;
  final DateTime timestamp;
  final String location;
}

class _AccessLogCard extends StatelessWidget {
  const _AccessLogCard({
    required this.log,
    required this.isFirst,
    required this.isLast,
  });

  final _AccessLogEntry log;
  final bool isFirst;
  final bool isLast;

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (actionColor, actionIcon, actionText) = switch (log.action) {
      AccessAction.unlock => (
        Colors.green,
        Icons.lock_open_rounded,
        'Unlocked',
      ),
      AccessAction.lock => (Colors.orange, Icons.lock_rounded, 'Locked'),
      AccessAction.autoLock => (
        Colors.blue,
        Icons.timer_rounded,
        'Auto-locked',
      ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Container(
                    width: 2,
                    height: 16,
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: actionColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : Insets.md),
              padding: const EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: CornerRadius.card,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(actionIcon, size: 18, color: actionColor),
                          const SizedBox(width: Insets.xs),
                          Text(
                            actionText,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: actionColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatTime(log.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'By ${log.user}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        log.location,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
