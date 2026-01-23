import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/access_log.dart';
import '../../providers/access_control/access_control_cubit.dart';
import '../../services/container_access_service.dart';
import '../../utils/ui_constants.dart';

/// Displays access log entries for container lock/unlock events.
/// Uses [AccessControlCubit] to fetch real data from the API.
class AccessLogsScreen extends StatelessWidget {
  const AccessLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AccessControlCubit(
        containerAccessService: context.read<ContainerAccessService>(),
      )..initialize(),
      child: const _AccessLogsView(),
    );
  }
}

class _AccessLogsView extends StatefulWidget {
  const _AccessLogsView();

  @override
  State<_AccessLogsView> createState() => _AccessLogsViewState();
}

class _AccessLogsViewState extends State<_AccessLogsView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<AccessControlCubit>().loadMoreLogs();
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<AccessControlCubit>().refreshLogs(),
          ),
        ],
      ),
      body: BlocConsumer<AccessControlCubit, AccessControlState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Theme.of(context).colorScheme.error,
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Theme.of(context).colorScheme.onError,
                  onPressed: () =>
                      context.read<AccessControlCubit>().refreshLogs(),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return switch (state.status) {
            AccessControlStatus.initial ||
            AccessControlStatus.loading => const _LoadingView(),
            AccessControlStatus.error when state.logs.isEmpty => _ErrorView(
              message: state.errorMessage,
            ),
            _ => _LogsListView(
              logs: state.logs,
              hasMoreLogs: state.hasMoreLogs,
              isLoadingMore: state.status == AccessControlStatus.loading,
              scrollController: _scrollController,
            ),
          };
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: Insets.md),
          Text('Loading access logs...'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: Insets.md),
            Text(
              'Failed to load logs',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (message != null) ...[
              const SizedBox(height: Insets.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
            const SizedBox(height: Insets.lg),
            FilledButton.icon(
              onPressed: () => context.read<AccessControlCubit>().refreshLogs(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogsListView extends StatelessWidget {
  const _LogsListView({
    required this.logs,
    required this.hasMoreLogs,
    required this.isLoadingMore,
    required this.scrollController,
  });

  final List<AccessLogEntry> logs;
  final bool hasMoreLogs;
  final bool isLoadingMore;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const _EmptyView();
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<AccessControlCubit>().refreshLogs();
      },
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(Insets.lg),
        itemCount: logs.length + (hasMoreLogs ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= logs.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: Insets.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final log = logs[index];
          final isFirst = index == 0;
          final isLast = index == logs.length - 1 && !hasMoreLogs;

          return _AccessLogCard(log: log, isFirst: isFirst, isLast: isLast);
        },
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: Insets.md),
          Text(
            'No access logs yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Lock/unlock actions will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessLogCard extends StatelessWidget {
  const _AccessLogCard({
    required this.log,
    required this.isFirst,
    required this.isLast,
  });

  final AccessLogEntry log;
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
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  (Color, IconData, String) _getActionStyle(AccessAction action) {
    return switch (action) {
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
  }

  IconData _getMethodIcon(AccessMethod method) {
    return switch (method) {
      AccessMethod.app => Icons.smartphone_rounded,
      AccessMethod.rfid => Icons.contactless_rounded,
      AccessMethod.voice => Icons.mic_rounded,
      AccessMethod.auto => Icons.timer_rounded,
    };
  }

  String _getMethodLabel(AccessMethod method) {
    return switch (method) {
      AccessMethod.app => 'App',
      AccessMethod.rfid => 'RFID',
      AccessMethod.voice => 'Voice',
      AccessMethod.auto => 'Auto',
    };
  }

  Color _getStatusColor(AccessStatus status, ColorScheme colorScheme) {
    return switch (status) {
      AccessStatus.success => Colors.green,
      AccessStatus.failed => colorScheme.error,
      AccessStatus.denied => Colors.orange,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (actionColor, actionIcon, actionText) = _getActionStyle(log.action);
    final statusColor = _getStatusColor(log.status, colorScheme);

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
                    color: log.status == AccessStatus.success
                        ? actionColor
                        : statusColor,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'By ${log.userName}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Status badge
                      if (log.status != AccessStatus.success)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            log.status.name.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
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
                      const Spacer(),
                      // Method indicator
                      Icon(
                        _getMethodIcon(log.method),
                        size: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getMethodLabel(log.method),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  // Error message if failed
                  if (log.errorMessage != null) ...[
                    const SizedBox(height: Insets.xs),
                    Container(
                      padding: const EdgeInsets.all(Insets.sm),
                      decoration: BoxDecoration(
                        color: colorScheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 14,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: Insets.xs),
                          Expanded(
                            child: Text(
                              log.errorMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Photo thumbnail if available
                  if (log.photoUrl != null) ...[
                    const SizedBox(height: Insets.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        log.photoUrl!,
                        height: 60,
                        width: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 60,
                            width: 80,
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
