import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/robot_motion_command.dart';
import '../../providers/robot_controller/robot_controller_cubit.dart';
import '../../providers/robot_controller/robot_controller_state.dart';
import '../../utils/ui_constants.dart';

/// A directional control pad for sending movement commands to the robot.
///
/// Displays four directional buttons (forward, backward, left, right) in a
/// cross pattern. Buttons are disabled while a command is being sent.
class DirectionalPad extends StatelessWidget {
  const DirectionalPad({super.key});

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
