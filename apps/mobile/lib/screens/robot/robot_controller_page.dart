import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../providers/robot_controller/robot_controller_cubit.dart';
import '../../providers/robot_controller/robot_controller_state.dart';
import '../../services/robot_api_service.dart';
import '../../services/robot_discovery_service.dart';
import '../../utils/ui_constants.dart';
import '../../widgets/robot/robot_widgets.dart';

/// Main screen for controlling the robot via directional commands.
///
/// Provides:
/// - Connection status and telemetry display
/// - Device picker for selecting available robots
/// - Directional pad for sending movement commands
/// - Emergency stop functionality
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
                      ConnectionStatusCard(
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
                              child: const DirectionalPad(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: Insets.md),
                      const CommandFooter(),
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
          BlocProvider.value(value: cubit, child: const RobotDeviceSheet()),
    );
  }
}
