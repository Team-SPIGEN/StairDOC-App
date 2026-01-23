import 'package:flutter/material.dart';

import '../../utils/ui_constants.dart';

/// Displays the queue of pending, active, and completed deliveries.
class DeliveryQueueScreen extends StatelessWidget {
  const DeliveryQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Delivery Queue'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
            ],
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.6),
            indicatorColor: colorScheme.primary,
          ),
        ),
        body: TabBarView(
          children: [
            _DeliveryList(
              deliveries: [
                _DeliveryItem(
                  id: 'DEL-001',
                  from: 'Office 201',
                  to: 'Office 305',
                  status: DeliveryStatus.pending,
                  time: '10:30 AM',
                ),
                _DeliveryItem(
                  id: 'DEL-002',
                  from: 'Reception',
                  to: 'Office 412',
                  status: DeliveryStatus.pending,
                  time: '11:00 AM',
                ),
              ],
            ),
            _DeliveryList(
              deliveries: [
                _DeliveryItem(
                  id: 'DEL-003',
                  from: 'Office 102',
                  to: 'Office 208',
                  status: DeliveryStatus.active,
                  time: '9:45 AM',
                ),
              ],
            ),
            _DeliveryList(
              deliveries: [
                _DeliveryItem(
                  id: 'DEL-004',
                  from: 'Office 301',
                  to: 'Office 105',
                  status: DeliveryStatus.completed,
                  time: '9:00 AM',
                ),
                _DeliveryItem(
                  id: 'DEL-005',
                  from: 'HR Department',
                  to: 'Finance',
                  status: DeliveryStatus.completed,
                  time: '8:30 AM',
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('New delivery scheduling coming soon!'),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('New Delivery'),
        ),
      ),
    );
  }
}

enum DeliveryStatus { pending, active, completed }

class _DeliveryItem {
  const _DeliveryItem({
    required this.id,
    required this.from,
    required this.to,
    required this.status,
    required this.time,
  });

  final String id;
  final String from;
  final String to;
  final DeliveryStatus status;
  final String time;
}

class _DeliveryList extends StatelessWidget {
  const _DeliveryList({required this.deliveries});

  final List<_DeliveryItem> deliveries;

  @override
  Widget build(BuildContext context) {
    if (deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: Insets.md),
            Text(
              'No deliveries',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(Insets.lg),
      itemCount: deliveries.length,
      separatorBuilder: (context, index) => const SizedBox(height: Insets.md),
      itemBuilder: (context, index) =>
          _DeliveryCard(delivery: deliveries[index]),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.delivery});

  final _DeliveryItem delivery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (statusColor, statusIcon) = switch (delivery.status) {
      DeliveryStatus.pending => (Colors.orange, Icons.schedule_rounded),
      DeliveryStatus.active => (
        colorScheme.primary,
        Icons.local_shipping_rounded,
      ),
      DeliveryStatus.completed => (Colors.green, Icons.check_circle_rounded),
    };

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                delivery.id,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      delivery.status.name.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Icon(
                Icons.arrow_upward_rounded,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text('From: ${delivery.from}', style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.arrow_downward_rounded,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text('To: ${delivery.to}', style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Scheduled: ${delivery.time}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
