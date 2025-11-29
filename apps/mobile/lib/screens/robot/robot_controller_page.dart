import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/robot_motion_command.dart';
import '../../providers/robot_controller/robot_controller_cubit.dart';
import '../../providers/robot_controller/robot_controller_state.dart';
import '../../services/robot_api_service.dart';
import '../../services/robot_discovery_service.dart';
import '../../utils/ui_constants.dart';
import '../../widgets/custom_button.dart';

class RobotControllerPage extends StatelessWidget {
  const RobotControllerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RobotControllerCubit(
        robotApiService: RobotApiService(),
        discoveryService: RobotDiscoveryService(),
      )..initialize(),
      child: const _RobotControllerView(),
    );
  }
}

class _RobotControllerView extends StatelessWidget {
  const _RobotControllerView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<RobotControllerCubit, RobotControllerState>(
      listenWhen: (previous, current) =>
          current.errorTimestamp != null &&
          current.errorTimestamp != previous.errorTimestamp,
      listener: (context, state) {
        final message = state.errorMessage ?? 'Unexpected controller error.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Robot Controller'),
          actions: [
            IconButton(
              tooltip: 'Reconnect',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () =>
                  context.read<RobotControllerCubit>().refreshStatus(),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewportConstraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(Insets.lg),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: viewportConstraints.maxHeight,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ConnectionStatusCard(
                        onManageDevices: () => _showDevicePicker(context),
                      ),
                      const SizedBox(height: Insets.lg),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final targetSize = min(constraints.maxWidth, 360.0);
                          return Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: targetSize,
                              height: targetSize,
                              child: const _DirectionalPad(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: Insets.md),
                      _CommandFooter(theme: theme),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showDevicePicker(BuildContext context) async {
    final cubit = context.read<RobotControllerCubit>();
    unawaited(cubit.discoverRobots());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const _RobotDeviceSheet()),
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({required this.onManageDevices});

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
              _TelemetryRow(state: state),
            ],
          ),
        );
      },
    );
  }
}

class _RobotDeviceSheet extends StatelessWidget {
  const _RobotDeviceSheet();

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

class _TelemetryRow extends StatelessWidget {
  const _TelemetryRow({required this.state});

  final RobotControllerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final tiles = <_TelemetryTile>[
      _TelemetryTile(
        label: 'Battery',
        value: state.batteryPercentage != null
            ? '${(state.batteryPercentage!).toStringAsFixed(0)}%'
            : '–',
        icon: Icons.bolt_rounded,
      ),
      _TelemetryTile(
        label: 'Floor',
        value: state.floor?.toString() ?? '–',
        icon: Icons.stairs_rounded,
      ),
      _TelemetryTile(
        label: 'Speed',
        value: state.linearVelocity != null
            ? '${state.linearVelocity!.toStringAsFixed(2)} m/s'
            : '–',
        icon: Icons.speed_rounded,
      ),
    ];

    Widget buildCard(_TelemetryTile tile) {
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

class _TelemetryTile {
  const _TelemetryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _DirectionalPad extends StatelessWidget {
  const _DirectionalPad();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RobotControllerCubit, RobotControllerState>(
      buildWhen: (previous, current) => previous.isSending != current.isSending,
      builder: (context, state) {
        final isBusy = state.isSending;
        return AspectRatio(
          aspectRatio: 1,
          child: Column(
            children: [
              _PadRow(
                children: [
                  const Spacer(),
                  _PadButton(
                    command: RobotMotionCommand.forward,
                    icon: Icons.keyboard_arrow_up_rounded,
                    isBusy: isBusy,
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: Insets.sm),
              _PadRow(
                children: [
                  _PadButton(
                    command: RobotMotionCommand.left,
                    icon: Icons.keyboard_arrow_left_rounded,
                    isBusy: isBusy,
                  ),
                  const Spacer(),
                  _PadButton(
                    command: RobotMotionCommand.right,
                    icon: Icons.keyboard_arrow_right_rounded,
                    isBusy: isBusy,
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              _PadRow(
                children: [
                  const Spacer(),
                  _PadButton(
                    command: RobotMotionCommand.backward,
                    icon: Icons.keyboard_arrow_down_rounded,
                    isBusy: isBusy,
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PadRow extends StatelessWidget {
  const _PadRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({
    required this.command,
    required this.icon,
    required this.isBusy,
  });

  final RobotMotionCommand command;
  final IconData icon;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RobotControllerCubit>();
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xs),
        child: FilledButton(
          onPressed: isBusy ? null : () => cubit.sendCommand(command),
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: colorScheme.primary,
            shape: RoundedRectangleBorder(borderRadius: CornerRadius.button),
          ),
          child: Icon(icon, size: 42, color: colorScheme.onPrimary),
        ),
      ),
    );
  }
}

class _CommandFooter extends StatelessWidget {
  const _CommandFooter({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RobotControllerCubit, RobotControllerState>(
      builder: (context, state) {
        final lastCommandLabel = state.lastCommand?.label ?? 'None';
        final lastCommandTime = state.lastUpdated;
        final commandMeta = lastCommandTime != null
            ? ' • ${TimeOfDay.fromDateTime(lastCommandTime).format(context)}'
            : '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Last command: $lastCommandLabel$commandMeta',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: Insets.sm),
            CustomButton(
              label: state.isSending ? 'Sending…' : 'Emergency Stop',
              variant: CustomButtonVariant.secondary,
              leadingIcon: Icons.warning_amber_rounded,
              onPressed: state.isSending
                  ? null
                  : () => context.read<RobotControllerCubit>().sendCommand(
                      RobotMotionCommand.stop,
                    ),
            ),
          ],
        );
      },
    );
  }
}
