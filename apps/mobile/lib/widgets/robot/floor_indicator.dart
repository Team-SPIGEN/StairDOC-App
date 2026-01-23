/// Floor and zone indicator widget.
///
/// Displays current robot location with floor number,
/// zone identifier, and optional navigation target.
library;

import 'package:flutter/material.dart';

import '../../models/telemetry.dart';
import '../../utils/ui_constants.dart';

/// Visual floor and zone indicator.
///
/// Displays:
/// - Current floor number prominently
/// - Zone identifier if available
/// - Target floor/zone if navigating
class FloorIndicator extends StatelessWidget {
  const FloorIndicator({
    super.key,
    required this.floor,
    this.zone,
    this.targetFloor,
    this.targetZone,
    this.size = FloorIndicatorSize.medium,
    this.showLabel = true,
  });

  /// Create from LocationData and MotionData models.
  factory FloorIndicator.fromTelemetry(
    LocationData location, {
    MotionData? motion,
    FloorIndicatorSize size = FloorIndicatorSize.medium,
    bool showLabel = true,
  }) {
    return FloorIndicator(
      floor: location.floor,
      zone: location.zone,
      targetFloor: motion?.targetFloor,
      targetZone: motion?.targetZone,
      size: size,
      showLabel: showLabel,
    );
  }

  final int floor;
  final String? zone;
  final int? targetFloor;
  final String? targetZone;
  final FloorIndicatorSize size;
  final bool showLabel;

  bool get _isNavigating => targetFloor != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (iconSize, textStyle, padding) = switch (size) {
      FloorIndicatorSize.small => (
        16.0,
        theme.textTheme.labelMedium,
        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      FloorIndicatorSize.medium => (
        20.0,
        theme.textTheme.bodyLarge,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      FloorIndicatorSize.large => (
        24.0,
        theme.textTheme.titleLarge,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.stairs_rounded,
            size: iconSize,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLabel)
                Text(
                  'Floor',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              Row(
                children: [
                  Text(
                    '$floor',
                    style: textStyle?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (zone != null) ...[
                    Text(
                      ' • Zone $zone',
                      style: textStyle?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (_isNavigating) ...[
            const SizedBox(width: 12),
            Icon(
              Icons.arrow_forward_rounded,
              size: iconSize * 0.8,
              color: colorScheme.tertiary,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showLabel)
                  Text(
                    'Target',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.tertiary.withValues(alpha: 0.8),
                    ),
                  ),
                Text(
                  targetZone != null
                      ? '$targetFloor • $targetZone'
                      : '$targetFloor',
                  style: textStyle?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Size variants for floor indicator.
enum FloorIndicatorSize { small, medium, large }

/// Compact floor chip for inline display.
class FloorChip extends StatelessWidget {
  const FloorChip({super.key, required this.floor, this.zone});

  final int floor;
  final String? zone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stairs_rounded, size: 14, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            zone != null ? 'F$floor • $zone' : 'Floor $floor',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Detailed location card showing all location info.
class LocationCard extends StatelessWidget {
  const LocationCard({super.key, required this.location, this.motion});

  final LocationData location;
  final MotionData? motion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Location',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          _LocationRow(
            label: 'Floor',
            value: '${location.floor}',
            icon: Icons.stairs_rounded,
          ),
          if (location.zone != null) ...[
            const SizedBox(height: Insets.xs),
            _LocationRow(
              label: 'Zone',
              value: location.zone!,
              icon: Icons.grid_view_rounded,
            ),
          ],
          if (location.room != null) ...[
            const SizedBox(height: Insets.xs),
            _LocationRow(
              label: 'Room',
              value: location.room!,
              icon: Icons.meeting_room_rounded,
            ),
          ],
          if (location.x != null && location.y != null) ...[
            const SizedBox(height: Insets.xs),
            _LocationRow(
              label: 'Position',
              value:
                  '(${location.x!.toStringAsFixed(1)}, ${location.y!.toStringAsFixed(1)})',
              icon: Icons.my_location_rounded,
            ),
          ],
          if (location.heading != null) ...[
            const SizedBox(height: Insets.xs),
            _LocationRow(
              label: 'Heading',
              value: '${location.heading!.toStringAsFixed(0)}°',
              icon: Icons.explore_rounded,
            ),
          ],
          if (motion?.targetFloor != null) ...[
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  Icons.navigation_rounded,
                  color: colorScheme.tertiary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Navigating to Floor ${motion!.targetFloor}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.tertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (motion?.targetZone != null)
                  Text(
                    ' • Zone ${motion!.targetZone}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.tertiary.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

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
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
