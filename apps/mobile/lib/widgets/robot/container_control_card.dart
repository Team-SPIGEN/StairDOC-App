/// Card widget for controlling container lock/unlock.
///
/// Displays current container status and provides lock/unlock buttons.
/// Integrates with [AccessControlCubit] for state management.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/access_log.dart';
import '../../providers/access_control/access_control_cubit.dart';
import '../../utils/ui_constants.dart';

/// Card showing container status with lock/unlock controls.
///
/// Displays:
/// - Current lock status (locked/unlocked/unknown)
/// - Lock/unlock action buttons
/// - Last action timestamp
/// - Loading states during operations
class ContainerControlCard extends StatelessWidget {
  const ContainerControlCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccessControlCubit, AccessControlState>(
      builder: (context, state) {
        return _ContainerControlCardContent(state: state);
      },
    );
  }
}

class _ContainerControlCardContent extends StatelessWidget {
  const _ContainerControlCardContent({required this.state});

  final AccessControlState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isLoading = state.status == AccessControlStatus.loading;
    final containerStatus = state.containerStatus;
    final isLocked = containerStatus?.isLocked ?? true;
    final isOperating = state.isOperationInProgress;

    return Container(
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
          // Header with title and status
          Row(
            children: [
              Icon(
                Icons.inventory_2_rounded,
                color: colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  'Container Control',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusBadge(isLocked: isLocked, isLoading: isLoading),
            ],
          ),
          const SizedBox(height: Insets.md),

          // Status details
          if (containerStatus != null) ...[
            if (containerStatus.lastActionBy != null)
              _StatusDetailRow(
                icon: Icons.person_outline_rounded,
                label: 'Last User',
                value: containerStatus.lastActionBy!,
              ),
            if (containerStatus.lastActionAt != null) ...[
              const SizedBox(height: Insets.xs),
              _StatusDetailRow(
                icon: Icons.access_time_rounded,
                label: 'Last Action',
                value: _formatLastAction(
                  containerStatus.lastAction,
                  containerStatus.lastActionAt!,
                ),
              ),
            ],
          ],

          if (state.errorMessage != null) ...[
            const SizedBox(height: Insets.sm),
            Container(
              padding: const EdgeInsets.all(Insets.sm),
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: Insets.xs),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: Insets.md),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Unlock',
                  icon: Icons.lock_open_rounded,
                  isActive: isLocked,
                  isLoading: state.isUnlocking,
                  isDisabled: !isLocked || isOperating,
                  color: Colors.green,
                  onPressed: () {
                    context.read<AccessControlCubit>().unlock();
                  },
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: _ActionButton(
                  label: 'Lock',
                  icon: Icons.lock_rounded,
                  isActive: !isLocked,
                  isLoading: state.isLocking,
                  isDisabled: isLocked || isOperating,
                  color: Colors.orange,
                  onPressed: () {
                    context.read<AccessControlCubit>().lock();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatLastAction(AccessAction? action, DateTime time) {
    final actionLabel = action?.displayName ?? 'Unknown';
    final diff = DateTime.now().difference(time);

    final timeLabel = switch (diff.inMinutes) {
      < 1 => 'just now',
      < 60 => '${diff.inMinutes}m ago',
      < 1440 => '${diff.inHours}h ago',
      _ => '${diff.inDays}d ago',
    };

    return '$actionLabel $timeLabel';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isLocked, required this.isLoading});

  final bool isLocked;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue,
              ),
            ),
            SizedBox(width: 6),
            Text('Loading'),
          ],
        ),
      );
    }

    final (color, icon, label) = isLocked
        ? (Colors.orange, Icons.lock_rounded, 'Locked')
        : (Colors.green, Icons.lock_open_rounded, 'Unlocked');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDetailRow extends StatelessWidget {
  const _StatusDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: Insets.xs),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.isLoading,
    required this.isDisabled,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final bool isLoading;
  final bool isDisabled;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveColor = isActive
        ? color
        : colorScheme.onSurface.withValues(alpha: 0.3);

    return Material(
      color: isActive
          ? color.withValues(alpha: 0.1)
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: Insets.md,
            horizontal: Insets.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: effectiveColor,
                  ),
                )
              else
                Icon(icon, size: 18, color: effectiveColor),
              const SizedBox(width: Insets.xs),
              Text(
                isLoading ? '${label}ing...' : label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: effectiveColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
