import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/robot_motion_command.dart';
import '../../providers/robot_controller/robot_controller_cubit.dart';
import '../../providers/robot_controller/robot_controller_state.dart';
import '../../utils/ui_constants.dart';
import 'telemetry_row.dart';

/// Card displaying robot connection status, telemetry, and device management.
///
/// Shows:
/// - Connection status indicator and label
/// - Status message and last update time
/// - Selected robot name and address
/// - Device management button
/// - Telemetry data (battery, floor, speed)
class ConnectionStatusCard extends StatelessWidget {
  const ConnectionStatusCard({super.key, required this.onManageDevices});

  /// Callback invoked when the user taps the device management button.
  final VoidCallback onManageDevices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<RobotControllerCubit, RobotControllerState>(
      builder: (context, state) {
        final colorScheme = theme.colorScheme;
        final status = state.connectionStatus;
        final statusLabel = switch (status) {
          RobotConnectionStatus.disconnected => 'Disconnected',
          RobotConnectionStatus.connecting => 'Connecting…',
          RobotConnectionStatus.connected => 'Connected',
          RobotConnectionStatus.reconnecting => 'Reconnecting…',
          RobotConnectionStatus.error => 'Error',
        };

        final indicatorColor = switch (status) {
          RobotConnectionStatus.connected => colorScheme.primary,
          RobotConnectionStatus.connecting => colorScheme.tertiary,
          RobotConnectionStatus.reconnecting => colorScheme.tertiary,
          RobotConnectionStatus.error => colorScheme.error,
          RobotConnectionStatus.disconnected => colorScheme.outline,
        };

        final statusMessage = state.statusMessage ?? 'Waiting for telemetry…';
        final lastUpdate = state.statusTimestamp;
        final lastUpdateLabel = lastUpdate != null
            ? 'Last update ${TimeOfDay.fromDateTime(lastUpdate).format(context)}'
            : 'No updates received yet';
        final selectedRobot = state.selectedRobot;
        final robotTitle = selectedRobot?.name ?? 'No robot selected';
        final robotSubtitle = selectedRobot != null
            ? selectedRobot.addressLabel
            : 'Tap Connect robot to pair with an available device.';

        Widget buildManageButton() {
          final label = state.isScanning
              ? 'Scanning…'
              : selectedRobot != null
              ? 'Change robot'
              : 'Connect robot';
          final child = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.isScanning)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.precision_manufacturing_outlined, size: 18),
              const SizedBox(width: Insets.xs),
              Text(label),
            ],
          );
          return OutlinedButton(
            onPressed: state.isScanning ? null : onManageDevices,
            child: child,
          );
        }

        final discoveryError = state.discoveryError;
        final lastScan = state.discoveryTimestamp;
        final lastScanLabel = lastScan != null
            ? 'Last scan ${TimeOfDay.fromDateTime(lastScan).format(context)}'
            : null;

        return Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: CornerRadius.card,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Text(
                    statusLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Stop robot',
                    icon: const Icon(Icons.front_hand_rounded),
                    onPressed: () => context
                        .read<RobotControllerCubit>()
                        .sendCommand(RobotMotionCommand.stop),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              Text(statusMessage, style: theme.textTheme.bodyMedium),
              const SizedBox(height: Insets.xs),
              Text(
                lastUpdateLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: Insets.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          robotTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          robotSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  buildManageButton(),
                ],
              ),
              if (state.isScanning) ...[
                const SizedBox(height: Insets.sm),
                const LinearProgressIndicator(minHeight: 3),
              ],
              if (discoveryError != null) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  discoveryError,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
              if (lastScanLabel != null) ...[
                const SizedBox(height: Insets.xs),
                Text(
                  lastScanLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
              const SizedBox(height: Insets.md),
              TelemetryRow(state: state),
            ],
          ),
        );
      },
    );
  }
}
