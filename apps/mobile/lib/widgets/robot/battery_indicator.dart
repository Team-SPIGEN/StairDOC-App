/// Battery indicator widget with visual level display.
///
/// Shows battery percentage with color-coded fill level
/// and optional charging indicator.
library;

import 'package:flutter/material.dart';

import '../../models/telemetry.dart';

/// Visual battery level indicator.
///
/// Displays:
/// - Battery icon with fill level
/// - Percentage text
/// - Charging animation when charging
/// - Color-coded by level (green/yellow/orange/red)
class BatteryIndicator extends StatelessWidget {
  const BatteryIndicator({
    super.key,
    required this.percentage,
    this.isCharging = false,
    this.size = BatteryIndicatorSize.medium,
    this.showPercentage = true,
    this.showLabel = false,
  });

  /// Create from BatteryStatus model.
  factory BatteryIndicator.fromStatus(
    BatteryStatus status, {
    BatteryIndicatorSize size = BatteryIndicatorSize.medium,
    bool showPercentage = true,
    bool showLabel = false,
  }) {
    return BatteryIndicator(
      percentage: status.percentage,
      isCharging: status.isCharging,
      size: size,
      showPercentage: showPercentage,
      showLabel: showLabel,
    );
  }

  final int percentage;
  final bool isCharging;
  final BatteryIndicatorSize size;
  final bool showPercentage;
  final bool showLabel;

  Color get _color {
    if (percentage > 60) return Colors.green;
    if (percentage > 30) return Colors.yellow.shade700;
    if (percentage > 10) return Colors.orange;
    return Colors.red;
  }

  IconData get _icon {
    if (isCharging) return Icons.battery_charging_full_rounded;
    if (percentage > 90) return Icons.battery_full_rounded;
    if (percentage > 70) return Icons.battery_6_bar_rounded;
    if (percentage > 50) return Icons.battery_5_bar_rounded;
    if (percentage > 40) return Icons.battery_4_bar_rounded;
    if (percentage > 30) return Icons.battery_3_bar_rounded;
    if (percentage > 20) return Icons.battery_2_bar_rounded;
    if (percentage > 10) return Icons.battery_1_bar_rounded;
    return Icons.battery_0_bar_rounded;
  }

  double get _iconSize => switch (size) {
    BatteryIndicatorSize.small => 16,
    BatteryIndicatorSize.medium => 24,
    BatteryIndicatorSize.large => 32,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = switch (size) {
      BatteryIndicatorSize.small => theme.textTheme.labelSmall,
      BatteryIndicatorSize.medium => theme.textTheme.bodyMedium,
      BatteryIndicatorSize.large => theme.textTheme.titleMedium,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AnimatedBatteryIcon(
          icon: _icon,
          color: _color,
          size: _iconSize,
          isCharging: isCharging,
        ),
        if (showPercentage) ...[
          const SizedBox(width: 4),
          Text(
            '$percentage%',
            style: textStyle?.copyWith(
              color: _color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (showLabel) ...[
          const SizedBox(width: 4),
          Text(
            'Battery',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}

/// Size variants for battery indicator.
enum BatteryIndicatorSize { small, medium, large }

class _AnimatedBatteryIcon extends StatefulWidget {
  const _AnimatedBatteryIcon({
    required this.icon,
    required this.color,
    required this.size,
    required this.isCharging,
  });

  final IconData icon;
  final Color color;
  final double size;
  final bool isCharging;

  @override
  State<_AnimatedBatteryIcon> createState() => _AnimatedBatteryIconState();
}

class _AnimatedBatteryIconState extends State<_AnimatedBatteryIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isCharging) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AnimatedBatteryIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCharging != oldWidget.isCharging) {
      if (widget.isCharging) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCharging) {
      return Icon(widget.icon, color: widget.color, size: widget.size);
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Icon(
          widget.icon,
          color: widget.color.withValues(alpha: _animation.value),
          size: widget.size,
        );
      },
    );
  }
}

/// Compact battery chip for inline display.
class BatteryChip extends StatelessWidget {
  const BatteryChip({
    super.key,
    required this.percentage,
    this.isCharging = false,
  });

  final int percentage;
  final bool isCharging;

  Color get _color {
    if (percentage > 60) return Colors.green;
    if (percentage > 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCharging
                ? Icons.battery_charging_full_rounded
                : Icons.battery_std_rounded,
            size: 14,
            color: _color,
          ),
          const SizedBox(width: 4),
          Text(
            '$percentage%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: _color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
