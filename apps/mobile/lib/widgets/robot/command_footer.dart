import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/robot_motion_command.dart';
import '../../providers/robot_controller/robot_controller_cubit.dart';
import '../../providers/robot_controller/robot_controller_state.dart';
import '../../utils/ui_constants.dart';
import '../custom_button.dart';

/// Footer section displaying last command info and emergency stop button.
class CommandFooter extends StatelessWidget {
  const CommandFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
