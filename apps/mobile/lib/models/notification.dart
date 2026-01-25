/// Notification models for StairDOC app.
///
/// Matches backend schemas in services/api/app/schemas/notification.py
library;

import 'package:flutter/material.dart';

/// Types of notifications the system can send.
enum NotificationType {
  // Delivery events
  deliveryRequested('delivery_requested'),
  deliveryStarted('delivery_started'),
  deliveryInProgress('delivery_in_progress'),
  deliveryCompleted('delivery_completed'),
  deliveryFailed('delivery_failed'),
  deliveryCancelled('delivery_cancelled'),

  // Container events
  containerUnlocked('container_unlocked'),
  containerLocked('container_locked'),
  containerAccessDenied('container_access_denied'),

  // Robot status
  robotLowBattery('robot_low_battery'),
  robotCharging('robot_charging'),
  robotOffline('robot_offline'),
  robotError('robot_error'),
  robotArrived('robot_arrived'),

  // Navigation
  navigationStarted('navigation_started'),
  navigationBlocked('navigation_blocked'),
  emergencyStop('emergency_stop'),

  // System
  systemInfo('system_info'),
  systemWarning('system_warning'),
  systemError('system_error');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.systemInfo,
    );
  }

  /// Get an icon for this notification type.
  IconData get icon {
    switch (this) {
      case NotificationType.deliveryRequested:
        return Icons.add_box_outlined;
      case NotificationType.deliveryStarted:
        return Icons.local_shipping_outlined;
      case NotificationType.deliveryInProgress:
        return Icons.directions_walk;
      case NotificationType.deliveryCompleted:
        return Icons.check_circle_outline;
      case NotificationType.deliveryFailed:
        return Icons.error_outline;
      case NotificationType.deliveryCancelled:
        return Icons.cancel_outlined;
      case NotificationType.containerUnlocked:
        return Icons.lock_open;
      case NotificationType.containerLocked:
        return Icons.lock;
      case NotificationType.containerAccessDenied:
        return Icons.no_encryption;
      case NotificationType.robotLowBattery:
        return Icons.battery_alert;
      case NotificationType.robotCharging:
        return Icons.battery_charging_full;
      case NotificationType.robotOffline:
        return Icons.signal_wifi_off;
      case NotificationType.robotError:
        return Icons.warning_amber;
      case NotificationType.robotArrived:
        return Icons.place;
      case NotificationType.navigationStarted:
        return Icons.navigation;
      case NotificationType.navigationBlocked:
        return Icons.block;
      case NotificationType.emergencyStop:
        return Icons.emergency;
      case NotificationType.systemInfo:
        return Icons.info_outline;
      case NotificationType.systemWarning:
        return Icons.warning;
      case NotificationType.systemError:
        return Icons.error;
    }
  }

  /// Get a color for this notification type.
  Color get color {
    switch (this) {
      case NotificationType.deliveryCompleted:
      case NotificationType.containerUnlocked:
      case NotificationType.robotArrived:
        return Colors.green;
      case NotificationType.deliveryStarted:
      case NotificationType.deliveryInProgress:
      case NotificationType.navigationStarted:
      case NotificationType.robotCharging:
        return Colors.blue;
      case NotificationType.deliveryRequested:
      case NotificationType.containerLocked:
      case NotificationType.systemInfo:
        return Colors.grey;
      case NotificationType.robotLowBattery:
      case NotificationType.navigationBlocked:
      case NotificationType.systemWarning:
        return Colors.orange;
      case NotificationType.deliveryFailed:
      case NotificationType.deliveryCancelled:
      case NotificationType.containerAccessDenied:
      case NotificationType.robotOffline:
      case NotificationType.robotError:
      case NotificationType.emergencyStop:
      case NotificationType.systemError:
        return Colors.red;
    }
  }
}

/// Priority levels for notifications.
enum NotificationPriority {
  low('low'),
  normal('normal'),
  high('high'),
  urgent('urgent');

  const NotificationPriority(this.value);
  final String value;

  static NotificationPriority fromString(String value) {
    return NotificationPriority.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationPriority.normal,
    );
  }
}

/// Channels through which notifications can be delivered.
enum NotificationChannel {
  push('push'),
  websocket('websocket'),
  email('email'),
  sms('sms');

  const NotificationChannel(this.value);
  final String value;

  static NotificationChannel fromString(String value) {
    return NotificationChannel.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationChannel.websocket,
    );
  }
}

/// A notification message.
class AppNotification {
  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.priority,
    required this.createdAt,
    this.robotId,
    this.deliveryId,
    this.data,
    this.channels = const [NotificationChannel.websocket],
    this.readAt,
    this.dismissedAt,
  });

  final String id;
  final String userId;
  final String? robotId;
  final String? deliveryId;
  final NotificationType type;
  final String title;
  final String body;
  final NotificationPriority priority;
  final Map<String, dynamic>? data;
  final List<NotificationChannel> channels;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? dismissedAt;

  /// Whether this notification has been read.
  bool get isRead => readAt != null;

  /// Whether this notification has been dismissed.
  bool get isDismissed => dismissedAt != null;

  /// Create from JSON.
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      robotId: json['robot_id'] as String?,
      deliveryId: json['delivery_id'] as String?,
      type: NotificationType.fromString(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      priority: NotificationPriority.fromString(json['priority'] as String),
      data: json['data'] as Map<String, dynamic>?,
      channels:
          (json['channels'] as List<dynamic>?)
              ?.map((e) => NotificationChannel.fromString(e as String))
              .toList() ??
          [NotificationChannel.websocket],
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      dismissedAt: json['dismissed_at'] != null
          ? DateTime.parse(json['dismissed_at'] as String)
          : null,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'robot_id': robotId,
      'delivery_id': deliveryId,
      'type': type.value,
      'title': title,
      'body': body,
      'priority': priority.value,
      'data': data,
      'channels': channels.map((c) => c.value).toList(),
      'created_at': createdAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'dismissed_at': dismissedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields.
  AppNotification copyWith({
    String? id,
    String? userId,
    String? robotId,
    String? deliveryId,
    NotificationType? type,
    String? title,
    String? body,
    NotificationPriority? priority,
    Map<String, dynamic>? data,
    List<NotificationChannel>? channels,
    DateTime? createdAt,
    DateTime? readAt,
    DateTime? dismissedAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      robotId: robotId ?? this.robotId,
      deliveryId: deliveryId ?? this.deliveryId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      priority: priority ?? this.priority,
      data: data ?? this.data,
      channels: channels ?? this.channels,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
    );
  }

  @override
  String toString() =>
      'AppNotification(id: $id, type: ${type.value}, title: $title)';
}

/// Response from listing notifications.
class NotificationListResponse {
  NotificationListResponse({
    required this.notifications,
    required this.total,
    required this.unreadCount,
    required this.page,
    required this.pageSize,
  });

  final List<AppNotification> notifications;
  final int total;
  final int unreadCount;
  final int page;
  final int pageSize;

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    return NotificationListResponse(
      notifications: (json['notifications'] as List<dynamic>)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      unreadCount: json['unread_count'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
    );
  }
}

/// User notification preferences.
class NotificationPreferences {
  NotificationPreferences({
    required this.userId,
    this.enabled = true,
    this.pushEnabled = true,
    this.emailEnabled = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.mutedTypes = const [],
    this.urgentOverridesQuietHours = true,
  });

  final String userId;
  final bool enabled;
  final bool pushEnabled;
  final bool emailEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool quietHoursEnabled;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final List<NotificationType> mutedTypes;
  final bool urgentOverridesQuietHours;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      userId: json['user_id'] as String,
      enabled: json['enabled'] as bool? ?? true,
      pushEnabled: json['push_enabled'] as bool? ?? true,
      emailEnabled: json['email_enabled'] as bool? ?? false,
      soundEnabled: json['sound_enabled'] as bool? ?? true,
      vibrationEnabled: json['vibration_enabled'] as bool? ?? true,
      quietHoursEnabled: json['quiet_hours_enabled'] as bool? ?? false,
      quietHoursStart: json['quiet_hours_start'] as String?,
      quietHoursEnd: json['quiet_hours_end'] as String?,
      mutedTypes:
          (json['muted_types'] as List<dynamic>?)
              ?.map((e) => NotificationType.fromString(e as String))
              .toList() ??
          [],
      urgentOverridesQuietHours:
          json['urgent_overrides_quiet_hours'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'enabled': enabled,
      'push_enabled': pushEnabled,
      'email_enabled': emailEnabled,
      'sound_enabled': soundEnabled,
      'vibration_enabled': vibrationEnabled,
      'quiet_hours_enabled': quietHoursEnabled,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
      'muted_types': mutedTypes.map((t) => t.value).toList(),
      'urgent_overrides_quiet_hours': urgentOverridesQuietHours,
    };
  }

  NotificationPreferences copyWith({
    String? userId,
    bool? enabled,
    bool? pushEnabled,
    bool? emailEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    List<NotificationType>? mutedTypes,
    bool? urgentOverridesQuietHours,
  }) {
    return NotificationPreferences(
      userId: userId ?? this.userId,
      enabled: enabled ?? this.enabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      mutedTypes: mutedTypes ?? this.mutedTypes,
      urgentOverridesQuietHours:
          urgentOverridesQuietHours ?? this.urgentOverridesQuietHours,
    );
  }
}

/// Notification statistics.
class NotificationStats {
  NotificationStats({
    required this.total,
    required this.unread,
    required this.byType,
    required this.byPriority,
  });

  final int total;
  final int unread;
  final Map<String, int> byType;
  final Map<String, int> byPriority;

  factory NotificationStats.fromJson(Map<String, dynamic> json) {
    return NotificationStats(
      total: json['total'] as int,
      unread: json['unread'] as int,
      byType: Map<String, int>.from(json['by_type'] as Map),
      byPriority: Map<String, int>.from(json['by_priority'] as Map),
    );
  }
}

/// Real-time notification event from WebSocket.
class NotificationEvent {
  NotificationEvent({
    required this.type,
    required this.notification,
    required this.timestamp,
  });

  final String type;
  final AppNotification notification;
  final DateTime timestamp;

  factory NotificationEvent.fromJson(Map<String, dynamic> json) {
    return NotificationEvent(
      type: json['type'] as String,
      notification: AppNotification.fromJson(
        json['notification'] as Map<String, dynamic>,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
