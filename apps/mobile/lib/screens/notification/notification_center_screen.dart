/// Notification Center screen showing all notifications.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/notification.dart';
import '../../providers/notification/notification_cubit.dart';
import '../../providers/notification/notification_state.dart';
import '../../widgets/notification/notification_tile.dart';

/// Screen displaying all notifications with filtering and actions.
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _scrollController = ScrollController();
  NotificationType? _filterType;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<NotificationCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          // Filter button
          PopupMenuButton<NotificationType?>(
            icon: Badge(
              isLabelVisible: _filterType != null,
              child: const Icon(Icons.filter_list),
            ),
            onSelected: (type) {
              setState(() {
                _filterType = type;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All notifications'),
              ),
              const PopupMenuDivider(),
              ...NotificationType.values
                  .take(10)
                  .map(
                    (type) => PopupMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(type.icon, size: 20, color: type.color),
                          const SizedBox(width: 8),
                          Text(_formatTypeName(type)),
                        ],
                      ),
                    ),
                  ),
            ],
          ),

          // Mark all as read
          BlocBuilder<NotificationCubit, NotificationState>(
            builder: (context, state) {
              if (state.unreadCount == 0) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.done_all),
                tooltip: 'Mark all as read',
                onPressed: () {
                  context.read<NotificationCubit>().markAllAsRead();
                },
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationCubit, NotificationState>(
        builder: (context, state) {
          // Connection status banner
          Widget? connectionBanner;
          if (!state.isConnected) {
            connectionBanner = MaterialBanner(
              content: Row(
                children: [
                  Icon(Icons.wifi_off, color: colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  const Text('Reconnecting to notification service...'),
                ],
              ),
              backgroundColor: colorScheme.errorContainer,
              actions: [
                TextButton(
                  onPressed: () {
                    context.read<NotificationCubit>().refresh();
                  },
                  child: const Text('Retry'),
                ),
              ],
            );
          }

          // Loading state
          if (state.isLoading && state.notifications.isEmpty) {
            return Column(
              children: [
                if (connectionBanner != null) connectionBanner,
                Expanded(
                  child: ListView.builder(
                    itemCount: 5,
                    itemBuilder: (context, index) =>
                        const NotificationTileSkeleton(),
                  ),
                ),
              ],
            );
          }

          // Filter notifications
          var notifications = state.notifications;
          if (_filterType != null) {
            notifications = notifications
                .where((n) => n.type == _filterType)
                .toList();
          }

          // Empty state
          if (notifications.isEmpty) {
            return Column(
              children: [
                if (connectionBanner != null) connectionBanner,
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filterType != null
                              ? 'No ${_formatTypeName(_filterType!).toLowerCase()} notifications'
                              : 'No notifications yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'ll see important updates here',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // Notification list
          return Column(
            children: [
              if (connectionBanner != null) connectionBanner,
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => context.read<NotificationCubit>().refresh(),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: notifications.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == notifications.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final notification = notifications[index];
                      return NotificationTile(
                        notification: notification,
                        onTap: () => _showNotificationDetail(notification),
                        onMarkAsRead: () {
                          context.read<NotificationCubit>().markAsRead(
                            notification.id,
                          );
                        },
                        onDismiss: () {
                          context.read<NotificationCubit>().dismiss(
                            notification.id,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // Test notification button (debug only)
      floatingActionButton: _buildTestButton(context),
    );
  }

  Widget? _buildTestButton(BuildContext context) {
    // Only show in debug mode
    assert(() {
      return true;
    }());

    return FloatingActionButton.extended(
      onPressed: () => _sendTestNotification(context),
      icon: const Icon(Icons.send),
      label: const Text('Test'),
    );
  }

  void _sendTestNotification(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Send Test Notification',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TestChip(
                  label: 'Delivery Started',
                  icon: Icons.local_shipping,
                  color: Colors.blue,
                  onTap: () {
                    context.read<NotificationCubit>().sendTestNotification(
                      title: 'Delivery Started',
                      body: 'Your delivery to Floor 3, Room 301 has begun.',
                      type: NotificationType.deliveryStarted,
                    );
                    Navigator.pop(context);
                  },
                ),
                _TestChip(
                  label: 'Delivery Complete',
                  icon: Icons.check_circle,
                  color: Colors.green,
                  onTap: () {
                    context.read<NotificationCubit>().sendTestNotification(
                      title: 'Delivery Completed',
                      body: 'Your delivery has arrived at Floor 3, Room 301.',
                      type: NotificationType.deliveryCompleted,
                    );
                    Navigator.pop(context);
                  },
                ),
                _TestChip(
                  label: 'Low Battery',
                  icon: Icons.battery_alert,
                  color: Colors.orange,
                  onTap: () {
                    context.read<NotificationCubit>().sendTestNotification(
                      title: 'Low Battery Warning',
                      body: 'Robot battery is at 15%. Please charge soon.',
                      type: NotificationType.robotLowBattery,
                    );
                    Navigator.pop(context);
                  },
                ),
                _TestChip(
                  label: 'Emergency Stop',
                  icon: Icons.emergency,
                  color: Colors.red,
                  onTap: () {
                    context.read<NotificationCubit>().sendTestNotification(
                      title: '⚠️ Emergency Stop',
                      body: 'Robot has stopped. Reason: Obstacle detected.',
                      type: NotificationType.emergencyStop,
                    );
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showNotificationDetail(AppNotification notification) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: notification.type.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    notification.type.icon,
                    color: notification.type.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _formatTypeName(notification.type),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(notification.body),
            if (notification.data != null && notification.data!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('Details', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...notification.data!.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        '${e.key}: ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(e.value.toString()),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatTypeName(NotificationType type) {
    final name = type.value.replaceAll('_', ' ');
    return name[0].toUpperCase() + name.substring(1);
  }
}

class _TestChip extends StatelessWidget {
  const _TestChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
