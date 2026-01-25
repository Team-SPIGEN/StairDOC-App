/// Notification state for BLoC pattern.
library;

import 'package:equatable/equatable.dart';

import '../../models/notification.dart';

/// Status of the notification state.
enum NotificationStatus { initial, loading, connected, disconnected, error }

/// State for notification management.
class NotificationState extends Equatable {
  const NotificationState({
    this.status = NotificationStatus.initial,
    this.notifications = const [],
    this.unreadCount = 0,
    this.preferences,
    this.stats,
    this.errorMessage,
    this.hasMore = true,
    this.currentPage = 1,
    this.isConnected = false,
  });

  /// Current status.
  final NotificationStatus status;

  /// List of notifications.
  final List<AppNotification> notifications;

  /// Number of unread notifications.
  final int unreadCount;

  /// User notification preferences.
  final NotificationPreferences? preferences;

  /// Notification statistics.
  final NotificationStats? stats;

  /// Error message if status is error.
  final String? errorMessage;

  /// Whether there are more notifications to load.
  final bool hasMore;

  /// Current page for pagination.
  final int currentPage;

  /// Whether WebSocket is connected.
  final bool isConnected;

  /// Whether loading is in progress.
  bool get isLoading => status == NotificationStatus.loading;

  /// Whether an error occurred.
  bool get hasError => status == NotificationStatus.error;

  /// Create a copy with updated fields.
  NotificationState copyWith({
    NotificationStatus? status,
    List<AppNotification>? notifications,
    int? unreadCount,
    NotificationPreferences? preferences,
    NotificationStats? stats,
    String? errorMessage,
    bool? hasMore,
    int? currentPage,
    bool? isConnected,
  }) {
    return NotificationState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      preferences: preferences ?? this.preferences,
      stats: stats ?? this.stats,
      errorMessage: errorMessage,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  @override
  List<Object?> get props => [
    status,
    notifications,
    unreadCount,
    preferences,
    stats,
    errorMessage,
    hasMore,
    currentPage,
    isConnected,
  ];
}
