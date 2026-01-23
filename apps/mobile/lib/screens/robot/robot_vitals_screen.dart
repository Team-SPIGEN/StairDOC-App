import 'package:flutter/material.dart';

import '../../utils/ui_constants.dart';

/// Displays real-time robot vitals including battery, connectivity,
/// sensor readings, and system health indicators.
class RobotVitalsScreen extends StatelessWidget {
  const RobotVitalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Robot Vitals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            _VitalCard(
              icon: Icons.battery_charging_full_rounded,
              title: 'Battery',
              value: '78%',
              subtitle: 'Estimated 4.5 hours remaining',
              color: Colors.green,
            ),
            const SizedBox(height: Insets.md),
            _VitalCard(
              icon: Icons.wifi_rounded,
              title: 'WiFi Signal',
              value: 'Strong',
              subtitle: 'Connected to StairDoc-Network',
              color: colorScheme.primary,
            ),
            const SizedBox(height: Insets.md),
            _VitalCard(
              icon: Icons.speed_rounded,
              title: 'Motor Status',
              value: 'Idle',
              subtitle: 'All motors operational',
              color: Colors.orange,
            ),
            const SizedBox(height: Insets.md),
            _VitalCard(
              icon: Icons.sensors_rounded,
              title: 'Sensors',
              value: '12/12 Active',
              subtitle: 'All proximity sensors online',
              color: Colors.teal,
            ),
            const SizedBox(height: Insets.md),
            _VitalCard(
              icon: Icons.thermostat_rounded,
              title: 'Temperature',
              value: '42°C',
              subtitle: 'Within normal range',
              color: Colors.deepOrange,
            ),
            const SizedBox(height: Insets.md),
            _VitalCard(
              icon: Icons.location_on_rounded,
              title: 'Current Location',
              value: 'Floor 2',
              subtitle: 'Zone A - Near elevator',
              color: Colors.indigo,
            ),
          ],
        ),
      ),
    );
  }
}

class _VitalCard extends StatelessWidget {
  const _VitalCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
