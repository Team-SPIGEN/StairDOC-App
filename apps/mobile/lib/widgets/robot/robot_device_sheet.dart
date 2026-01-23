import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../providers/robot_controller/robot_controller_cubit.dart';
import '../../providers/robot_controller/robot_controller_state.dart';
import '../../utils/ui_constants.dart';

/// Bottom sheet for selecting and connecting to discovered robots.
///
/// Displays a list of available robots discovered via mDNS or API fallback.
/// Allows the user to select a robot, rescan the network, and connect.
class RobotDeviceSheet extends StatelessWidget {
  const RobotDeviceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cubit = context.read<RobotControllerCubit>();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Insets.lg,
          right: Insets.lg,
          top: Insets.lg,
          bottom: Insets.lg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BlocBuilder<RobotControllerCubit, RobotControllerState>(
          builder: (context, state) {
            final robots = state.availableRobots;
            final isScanning = state.isScanning;
            final selected = state.selectedRobot;

            Widget buildList() {
              if (robots.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.md),
                  child: Text(
                    isScanning
                        ? 'Scanning for robots…'
                        : 'No robots discovered yet. Ensure the robot is powered on and connected to your network.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                );
              }

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: robots.length,
                  separatorBuilder: (_, index) =>
                      const SizedBox(height: Insets.xs),
                  itemBuilder: (context, index) {
                    final robot = robots[index];
                    final isSelected = selected?.id == robot.id;
                    final isConnected =
                        state.connectionStatus ==
                            RobotConnectionStatus.connected &&
                        isSelected;
                    final selectionIcon = isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded;

                    return ListTile(
                      enabled: !isScanning,
                      selected: isSelected,
                      onTap: isScanning ? null : () => cubit.selectRobot(robot),
                      leading: Icon(
                        selectionIcon,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                      title: Text(robot.name),
                      subtitle: Text(robot.addressLabel),
                      trailing: isConnected
                          ? Chip(
                              label: const Text('Connected'),
                              labelStyle: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimary,
                              ),
                              backgroundColor: colorScheme.primary,
                            )
                          : null,
                    );
                  },
                ),
              );
            }

            final discoveryError = state.discoveryError;
            final lastScan = state.discoveryTimestamp;
            final lastScanLabel = lastScan != null
                ? 'Last scan ${TimeOfDay.fromDateTime(lastScan).format(context)}'
                : null;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available robots',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                if (isScanning) const LinearProgressIndicator(minHeight: 3),
                if (isScanning) const SizedBox(height: Insets.sm),
                buildList(),
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isScanning
                            ? null
                            : () => cubit.discoverRobots(
                                autoConnectOnSingle: false,
                              ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Rescan'),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: selected == null || isScanning
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                cubit.connectToSelectedRobot();
                              },
                        icon: const Icon(Icons.wifi_rounded),
                        label: const Text('Connect'),
                      ),
                    ),
                  ],
                ),
                if (state.connectionStatus == RobotConnectionStatus.connected)
                  Padding(
                    padding: const EdgeInsets.only(top: Insets.sm),
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        cubit.disconnect();
                      },
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('Disconnect'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
