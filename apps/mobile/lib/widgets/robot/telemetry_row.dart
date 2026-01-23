import 'package:flutter/material.dart';

import '../../models/telemetry.dart';
import '../../providers/robot_controller/robot_controller_state.dart';
import '../../utils/ui_constants.dart';
import 'battery_indicator.dart';
import 'floor_indicator.dart';

/// Displays a row of telemetry data tiles (battery, floor, speed).
///
/// Adapts layout based on available width - stacks vertically on narrow
/// screens and displays horizontally on wider screens.
///
/// Can be constructed with either [RobotControllerState] (legacy) or
/// [TelemetryData] (WebSocket) for backward compatibility.
class TelemetryRow extends StatelessWidget {
  /// Creates a telemetry row from RobotControllerState (legacy).
  const TelemetryRow({super.key, required this.state}) : telemetry = null;

  /// Creates a telemetry row from WebSocket telemetry data.
  const TelemetryRow.fromTelemetry({
    super.key,
    required TelemetryData this.telemetry,
  }) : state = null;

  /// Legacy state from RobotControllerCubit.
  final RobotControllerState? state;

  /// WebSocket telemetry data.
  final TelemetryData? telemetry;

  @override
  Widget build(BuildContext context) {
    // Extract values from either source
    final int? batteryLevel;
    final bool isCharging;
    final int? floor;
    final String? zone;
    final double? speed;

    if (telemetry != null) {
      batteryLevel = telemetry!.battery.percentage;
      isCharging = telemetry!.battery.isCharging;
      floor = telemetry!.location.floor;
      zone = telemetry!.location.zone;
      speed = telemetry!.motion.linearVelocity;
    } else if (state != null) {
      batteryLevel = state!.batteryPercentage?.toInt();
      isCharging = false; // Legacy state doesn't track charging
      floor = state!.floor;
      zone = null; // Legacy state doesn't track zone
      speed = state!.linearVelocity;
    } else {
      batteryLevel = null;
      isCharging = false;
      floor = null;
      zone = null;
      speed = null;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 480;

        final tiles = [
          _TelemetryTile(
            label: 'Battery',
            child: batteryLevel != null
                ? BatteryChip(percentage: batteryLevel, isCharging: isCharging)
                : _PlaceholderChip(label: 'Battery', icon: Icons.bolt_rounded),
          ),
          _TelemetryTile(
            label: 'Location',
            child: floor != null
                ? FloorChip(floor: floor, zone: zone)
                : _PlaceholderChip(label: 'Floor', icon: Icons.stairs_rounded),
          ),
          _TelemetryTile(
            label: 'Speed',
            child: _SpeedChip(speed: speed),
          ),
        ];

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                tiles[i],
                if (i != tiles.length - 1) const SizedBox(height: Insets.sm),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              Expanded(child: tiles[i]),
              if (i != tiles.length - 1) const SizedBox(width: Insets.sm),
            ],
          ],
        );
      },
    );
  }
}

class _TelemetryTile extends StatelessWidget {
  const _TelemetryTile({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: Insets.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: CornerRadius.button,
        color: colorScheme.primary.withValues(alpha: 0.08),
      ),
      child: child,
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({this.speed});

  final double? speed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isMoving = speed != null && speed! > 0.01;
    final color = isMoving ? Colors.green : colorScheme.primary;

    return Row(
      children: [
        Icon(
          isMoving ? Icons.speed_rounded : Icons.pause_circle_outline_rounded,
          size: 20,
          color: color,
        ),
        const SizedBox(width: Insets.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Speed',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              speed != null ? '${speed!.toStringAsFixed(2)} m/s' : '–',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }
}

class _PlaceholderChip extends StatelessWidget {
  const _PlaceholderChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.outline),
        const SizedBox(width: Insets.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text('–', style: theme.textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}
