/// Robot vitals screen showing comprehensive robot status.
///
/// Displays all telemetry data including:
/// - Connection status
/// - Battery and charging status
/// - Location and navigation
/// - Motion data
/// - Sensor readings
/// - System health
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/telemetry.dart';
import '../../providers/telemetry/telemetry_cubit.dart';
import '../../services/telemetry_websocket_service.dart';
import '../../utils/ui_constants.dart';
import '../../widgets/robot/battery_indicator.dart';
import '../../widgets/robot/floor_indicator.dart';

/// Screen displaying comprehensive robot telemetry data.
class RobotVitalsScreen extends StatelessWidget {
  const RobotVitalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          TelemetryCubit(webSocketService: TelemetryWebSocketService())
            ..connect(includeSensors: true, includeSystem: true),
      child: const _RobotVitalsView(),
    );
  }
}

class _RobotVitalsView extends StatelessWidget {
  const _RobotVitalsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Robot Vitals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          BlocBuilder<TelemetryCubit, TelemetryState>(
            builder: (context, state) {
              return IconButton(
                icon: Icon(
                  state.isConnected
                      ? Icons.wifi_rounded
                      : Icons.wifi_off_rounded,
                ),
                onPressed: () {
                  if (state.isConnected) {
                    context.read<TelemetryCubit>().disconnect();
                  } else {
                    context.read<TelemetryCubit>().connect(
                      includeSensors: true,
                      includeSystem: true,
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<TelemetryCubit, TelemetryState>(
        builder: (context, state) {
          if (!state.hasTelemetry) {
            return _buildLoadingOrError(context, state);
          }

          return RefreshIndicator(
            onRefresh: () async {
              await context.read<TelemetryCubit>().reconnect(
                includeSensors: true,
                includeSystem: true,
              );
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ConnectionStatusHeader(state: state),
                  const SizedBox(height: Insets.lg),
                  _RobotStateCard(telemetry: state.telemetry!),
                  const SizedBox(height: Insets.md),
                  _BatteryCard(battery: state.telemetry!.battery),
                  const SizedBox(height: Insets.md),
                  LocationCard(
                    location: state.telemetry!.location,
                    motion: state.telemetry!.motion,
                  ),
                  const SizedBox(height: Insets.md),
                  _MotionCard(motion: state.telemetry!.motion),
                  if (state.telemetry!.sensors != null) ...[
                    const SizedBox(height: Insets.md),
                    _SensorsCard(sensors: state.telemetry!.sensors!),
                  ],
                  if (state.telemetry!.system != null) ...[
                    const SizedBox(height: Insets.md),
                    _SystemHealthCard(system: state.telemetry!.system!),
                  ],
                  const SizedBox(height: Insets.lg),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingOrError(BuildContext context, TelemetryState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (state.isConnecting || state.isReconnecting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: Insets.md),
            Text(
              state.isReconnecting ? 'Reconnecting...' : 'Connecting...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: colorScheme.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: Insets.md),
            Text('Not Connected', style: theme.textTheme.headlineSmall),
            if (state.errorMessage != null) ...[
              const SizedBox(height: Insets.sm),
              Text(
                state.errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: Insets.lg),
            FilledButton.icon(
              onPressed: () => context.read<TelemetryCubit>().connect(
                includeSensors: true,
                includeSystem: true,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatusHeader extends StatelessWidget {
  const _ConnectionStatusHeader({required this.state});

  final TelemetryState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (
      statusColor,
      statusIcon,
      statusLabel,
    ) = switch (state.connectionState) {
      WebSocketConnectionState.connected => (
        Colors.green,
        Icons.wifi_rounded,
        'Connected',
      ),
      WebSocketConnectionState.connecting => (
        colorScheme.tertiary,
        Icons.wifi_find_rounded,
        'Connecting',
      ),
      WebSocketConnectionState.reconnecting => (
        Colors.orange,
        Icons.wifi_protected_setup_rounded,
        'Reconnecting',
      ),
      WebSocketConnectionState.disconnected => (
        colorScheme.error,
        Icons.wifi_off_rounded,
        'Disconnected',
      ),
    };

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (state.lastUpdated != null)
          Text(
            'Updated ${_formatTime(state.lastUpdated!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 5) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }
}

class _RobotStateCard extends StatelessWidget {
  const _RobotStateCard({required this.telemetry});

  final TelemetryData telemetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final stateColor = telemetry.hasError
        ? colorScheme.error
        : telemetry.state.isActive
        ? Colors.green
        : colorScheme.primary;

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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: stateColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getStateIcon(telemetry.state),
              size: 32,
              color: stateColor,
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  telemetry.state.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: stateColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Robot ID: ${telemetry.robotId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (telemetry.activeDeliveryId != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Delivery #${telemetry.activeDeliveryId}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _ContainerStatusBadge(state: telemetry.containerState),
        ],
      ),
    );
  }

  IconData _getStateIcon(RobotState state) {
    return switch (state) {
      RobotState.idle => Icons.pause_circle_outline_rounded,
      RobotState.moving => Icons.directions_walk_rounded,
      RobotState.climbing => Icons.north_rounded,
      RobotState.descending => Icons.south_rounded,
      RobotState.delivering => Icons.local_shipping_rounded,
      RobotState.returning => Icons.home_rounded,
      RobotState.charging => Icons.battery_charging_full_rounded,
      RobotState.error => Icons.error_outline_rounded,
      RobotState.maintenance => Icons.build_rounded,
    };
  }
}

class _ContainerStatusBadge extends StatelessWidget {
  const _ContainerStatusBadge({required this.state});

  final ContainerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (color, icon, label) = switch (state) {
      ContainerState.locked => (Colors.orange, Icons.lock_rounded, 'Locked'),
      ContainerState.unlocked => (
        Colors.green,
        Icons.lock_open_rounded,
        'Unlocked',
      ),
      ContainerState.opening => (
        Colors.blue,
        Icons.lock_clock_rounded,
        'Opening',
      ),
      ContainerState.closing => (
        Colors.blue,
        Icons.lock_clock_rounded,
        'Closing',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.battery});

  final BatteryStatus battery;

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
                Icons.battery_std_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Battery',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              BatteryIndicator(
                percentage: battery.percentage,
                isCharging: battery.isCharging,
                size: BatteryIndicatorSize.large,
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          // Battery level bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: battery.percentage / 100,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: _getBatteryColor(battery.percentage),
            ),
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              if (battery.voltage != null)
                _BatteryDetailChip(
                  label: 'Voltage',
                  value: '${battery.voltage!.toStringAsFixed(1)}V',
                ),
              if (battery.temperature != null) ...[
                const SizedBox(width: Insets.sm),
                _BatteryDetailChip(
                  label: 'Temp',
                  value: '${battery.temperature!.toStringAsFixed(0)}°C',
                ),
              ],
              if (battery.estimatedRuntimeMinutes != null) ...[
                const SizedBox(width: Insets.sm),
                _BatteryDetailChip(
                  label: 'Runtime',
                  value: _formatRuntime(battery.estimatedRuntimeMinutes!),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _getBatteryColor(int level) {
    if (level > 60) return Colors.green;
    if (level > 30) return Colors.orange;
    return Colors.red;
  }

  String _formatRuntime(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
    return '${minutes}m';
  }
}

class _BatteryDetailChip extends StatelessWidget {
  const _BatteryDetailChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MotionCard extends StatelessWidget {
  const _MotionCard({required this.motion});

  final MotionData motion;

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
              Icon(Icons.speed_rounded, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Motion',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: motion.isMoving
                      ? Colors.green.withValues(alpha: 0.1)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  motion.isMoving ? 'Moving' : 'Stationary',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: motion.isMoving
                        ? Colors.green
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Linear',
                  value: motion.speedDisplay,
                  icon: Icons.straighten_rounded,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: _MetricTile(
                  label: 'Angular',
                  value: '${motion.angularVelocity.toStringAsFixed(2)} rad/s',
                  icon: Icons.rotate_right_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SensorsCard extends StatelessWidget {
  const _SensorsCard({required this.sensors});

  final SensorData sensors;

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
              Icon(Icons.sensors_rounded, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Sensors',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (sensors.stairDetected) _WarningChip(label: 'Stairs Ahead'),
              if (sensors.cliffDetected)
                _WarningChip(label: 'Cliff!', isError: true),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Front',
                  value:
                      '${sensors.frontDistance?.toStringAsFixed(0) ?? '--'} cm',
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: _MetricTile(
                  label: 'Rear',
                  value:
                      '${sensors.rearDistance?.toStringAsFixed(0) ?? '--'} cm',
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: _MetricTile(
                  label: 'Left',
                  value:
                      '${sensors.leftDistance?.toStringAsFixed(0) ?? '--'} cm',
                  icon: Icons.arrow_back_rounded,
                ),
              ),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: _MetricTile(
                  label: 'Right',
                  value:
                      '${sensors.rightDistance?.toStringAsFixed(0) ?? '--'} cm',
                  icon: Icons.arrow_forward_rounded,
                ),
              ),
            ],
          ),
          if (sensors.ambientTemperature != null ||
              sensors.humidity != null) ...[
            const SizedBox(height: Insets.sm),
            Row(
              children: [
                if (sensors.ambientTemperature != null)
                  _MetricTile(
                    label: 'Temp',
                    value:
                        '${sensors.ambientTemperature!.toStringAsFixed(0)}°C',
                    icon: Icons.thermostat_rounded,
                  ),
                if (sensors.humidity != null) ...[
                  const SizedBox(width: Insets.sm),
                  _MetricTile(
                    label: 'Humidity',
                    value: '${sensors.humidity!.toStringAsFixed(0)}%',
                    icon: Icons.water_drop_rounded,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SystemHealthCard extends StatelessWidget {
  const _SystemHealthCard({required this.system});

  final SystemHealth system;

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
                Icons.monitor_heart_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'System Health',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (system.uptimeSeconds != null)
                Text(
                  'Uptime: ${system.uptimeDisplay}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              Expanded(
                child: _UsageBar(
                  label: 'CPU',
                  value: system.cpuUsage,
                  icon: Icons.memory_rounded,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: _UsageBar(
                  label: 'Memory',
                  value: system.memoryUsage,
                  icon: Icons.storage_rounded,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: _UsageBar(
                  label: 'Disk',
                  value: system.diskUsage,
                  icon: Icons.sd_storage_rounded,
                ),
              ),
            ],
          ),
          if (system.wifiSignal != null) ...[
            const SizedBox(height: Insets.md),
            Row(
              children: [
                Icon(
                  Icons.wifi_rounded,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  'WiFi: ${system.wifiStrengthLabel} (${system.wifiSignal} dBm)',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
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

    return Container(
      padding: const EdgeInsets.all(Insets.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 16,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.label, this.value, required this.icon});

  final String label;
  final double? value;
  final IconData icon;

  Color _getColor(double val) {
    if (val > 80) return Colors.red;
    if (val > 60) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            Text(
              value != null ? '${value!.toStringAsFixed(0)}%' : '--',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (value ?? 0) / 100,
            minHeight: 4,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: value != null ? _getColor(value!) : colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _WarningChip extends StatelessWidget {
  const _WarningChip({required this.label, this.isError = false});

  final String label;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isError ? Colors.red : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isError ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
