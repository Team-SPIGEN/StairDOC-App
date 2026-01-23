/// Notification badge widget showing unread count.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../providers/notification/notification_cubit.dart';
import '../../providers/notification/notification_state.dart';

/// Badge showing unread notification count.
class NotificationBadge extends StatelessWidget {
  const NotificationBadge({
    super.key,
    required this.child,
    this.showZero = false,
    this.maxCount = 99,
    this.badgeColor,
    this.textColor,
    this.size = 18,
  });

  /// The widget to display the badge on (usually an icon).
  final Widget child;

  /// Whether to show the badge when count is zero.
  final bool showZero;

  /// Maximum count to display (shows "99+" if exceeded).
  final int maxCount;

  /// Background color of the badge.
  final Color? badgeColor;

  /// Text color of the count.
  final Color? textColor;

  /// Size of the badge.
  final double size;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationCubit, NotificationState>(
      builder: (context, state) {
        final count = state.unreadCount;

        if (count == 0 && !showZero) {
          return child;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              right: -6,
              top: -6,
              child: _Badge(
                count: count,
                maxCount: maxCount,
                color: badgeColor ?? Theme.of(context).colorScheme.error,
                textColor: textColor ?? Colors.white,
                size: size,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.count,
    required this.maxCount,
    required this.color,
    required this.textColor,
    required this.size,
  });

  final int count;
  final int maxCount;
  final Color color;
  final Color textColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final displayText = count > maxCount ? '$maxCount+' : count.toString();
    final isWide = displayText.length > 2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      padding: EdgeInsets.symmetric(horizontal: isWide ? 4 : 0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size / 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          displayText,
          style: TextStyle(
            color: textColor,
            fontSize: size * 0.6,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Animated notification icon with badge.
class NotificationIconButton extends StatelessWidget {
  const NotificationIconButton({
    super.key,
    required this.onPressed,
    this.icon = Icons.notifications_outlined,
    this.activeIcon = Icons.notifications,
    this.size = 24,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final IconData activeIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationCubit, NotificationState>(
      builder: (context, state) {
        final hasUnread = state.unreadCount > 0;

        return NotificationBadge(
          child: IconButton(
            onPressed: onPressed,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                hasUnread ? activeIcon : icon,
                key: ValueKey(hasUnread),
                size: size,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Connection status indicator for notifications.
class NotificationConnectionIndicator extends StatelessWidget {
  const NotificationConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationCubit, NotificationState>(
      builder: (context, state) {
        final isConnected = state.isConnected;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected ? Colors.green : Colors.orange,
            boxShadow: [
              BoxShadow(
                color: (isConnected ? Colors.green : Colors.orange).withValues(
                  alpha: 0.4,
                ),
                blurRadius: 4,
              ),
            ],
          ),
        );
      },
    );
  }
}
