import 'package:flutter/material.dart';

import '../../providers/robot_controller/robot_controller_state.dart';
import '../../utils/ui_constants.dart';

/// Displays a row of telemetry data tiles (battery, floor, speed).
///
/// Adapts layout based on available width - stacks vertically on narrow
/// screens and displays horizontally on wider screens.
class TelemetryRow extends StatelessWidget {
  const TelemetryRow({super.key, required this.state});

  final RobotControllerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final tiles = <_TelemetryTileData>[
      _TelemetryTileData(
        label: 'Battery',
        value: state.batteryPercentage != null
            ? '${(state.batteryPercentage!).toStringAsFixed(0)}%'
            : '–',
        icon: Icons.bolt_rounded,
      ),
      _TelemetryTileData(
        label: 'Floor',
        value: state.floor?.toString() ?? '–',
        icon: Icons.stairs_rounded,
      ),
      _TelemetryTileData(
        label: 'Speed',
        value: state.linearVelocity != null
            ? '${state.linearVelocity!.toStringAsFixed(2)} m/s'
            : '–',
        icon: Icons.speed_rounded,
      ),
    ];

    Widget buildCard(_TelemetryTileData tile) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm,
          vertical: Insets.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: CornerRadius.button,
          color: colorScheme.primary.withValues(alpha: 0.08),
        ),
        child: Row(
          children: [
            Icon(tile.icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: Insets.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tile.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(tile.value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 480;
        if (isCompact) {
          final children = <Widget>[];
          for (var i = 0; i < tiles.length; i++) {
            children.add(buildCard(tiles[i]));
            if (i != tiles.length - 1) {
              children.add(const SizedBox(height: Insets.sm));
            }
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              Expanded(child: buildCard(tiles[i])),
              if (i != tiles.length - 1) const SizedBox(width: Insets.sm),
            ],
          ],
        );
      },
    );
  }
}

/// Internal data class for telemetry tile configuration.
class _TelemetryTileData {
  const _TelemetryTileData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}
