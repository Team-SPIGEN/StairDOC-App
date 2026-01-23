/// Commands for controlling robot movement.
///
/// These map to directional controls on the robot controller screen
/// and are sent to the robot API for execution.
enum RobotMotionCommand { forward, backward, left, right, stop }

/// Extension providing utility methods for [RobotMotionCommand].
extension RobotMotionCommandX on RobotMotionCommand {
  /// Returns the API-compatible string value for this command.
  String get apiValue => switch (this) {
    RobotMotionCommand.forward => 'forward',
    RobotMotionCommand.backward => 'backward',
    RobotMotionCommand.left => 'left',
    RobotMotionCommand.right => 'right',
    RobotMotionCommand.stop => 'stop',
  };

  /// Returns a human-readable label for UI display.
  String get label => switch (this) {
    RobotMotionCommand.forward => 'Forward',
    RobotMotionCommand.backward => 'Backward',
    RobotMotionCommand.left => 'Left',
    RobotMotionCommand.right => 'Right',
    RobotMotionCommand.stop => 'Stop',
  };
}
