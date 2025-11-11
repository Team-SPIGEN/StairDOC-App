enum RobotMotionCommand {
  forward,
  backward,
  left,
  right,
  stop,
}

extension RobotMotionCommandX on RobotMotionCommand {
  String get apiValue => switch (this) {
        RobotMotionCommand.forward => 'forward',
        RobotMotionCommand.backward => 'backward',
        RobotMotionCommand.left => 'left',
        RobotMotionCommand.right => 'right',
        RobotMotionCommand.stop => 'stop',
      };

  String get label => switch (this) {
        RobotMotionCommand.forward => 'Forward',
        RobotMotionCommand.backward => 'Backward',
        RobotMotionCommand.left => 'Left',
        RobotMotionCommand.right => 'Right',
        RobotMotionCommand.stop => 'Stop',
      };
}
