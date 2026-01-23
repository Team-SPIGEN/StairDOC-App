/// NotificationCubit for managing notification state.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/notification.dart';
import '../../services/notification_service.dart';
import 'notification_state.dart';

/// Cubit for managing notifications.
class NotificationCubit extends Cubit<NotificationState> {
  NotificationCubit({required NotificationService notificationService})
    : _notificationService = notificationService,
      super(const NotificationState());

  final NotificationService _notificationService;
  StreamSubscription<AppNotification>? _notificationSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  String? _userId;

  static const int _pageSize = 20;

  /// Initialize and connect to notification stream.
  Future<void> initialize(String userId) async {
    _userId = userId;

    // Listen to incoming notifications
    _notificationSubscription = _notificationService.notificationStream.listen(
      _onNotificationReceived,
    );

    // Listen to connection state
    _connectionSubscription = _notificationService.connectionStateStream.listen(
      _onConnectionStateChanged,
    );

    // Connect to WebSocket
    await _notificationService.connect(userId);

    // Fetch initial data
    await refresh();
  }

  void _onNotificationReceived(AppNotification notification) {
    // Add new notification to the top of the list
    final updated = [notification, ...state.notifications];
    emit(
      state.copyWith(
        notifications: updated,
        unreadCount: state.unreadCount + 1,
      ),
    );
  }

  void _onConnectionStateChanged(bool isConnected) {
    emit(
      state.copyWith(
        isConnected: isConnected,
        status: isConnected
            ? NotificationStatus.connected
            : NotificationStatus.disconnected,
      ),
    );
  }

  /// Refresh notifications from the server.
  Future<void> refresh() async {
    if (_userId == null) return;

    emit(state.copyWith(status: NotificationStatus.loading));

    try {
      final response = await _notificationService.fetchNotifications(
        userId: _userId!,
        page: 1,
        pageSize: _pageSize,
      );

      emit(
        state.copyWith(
          status: state.isConnected
              ? NotificationStatus.connected
              : NotificationStatus.disconnected,
          notifications: response.notifications,
          unreadCount: response.unreadCount,
          hasMore: response.notifications.length >= _pageSize,
          currentPage: 1,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: NotificationStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Load more notifications (pagination).
  Future<void> loadMore() async {
    if (_userId == null || !state.hasMore || state.isLoading) return;

    final nextPage = state.currentPage + 1;

    try {
      final response = await _notificationService.fetchNotifications(
        userId: _userId!,
        page: nextPage,
        pageSize: _pageSize,
      );

      final combined = [...state.notifications, ...response.notifications];

      emit(
        state.copyWith(
          notifications: combined,
          hasMore: response.notifications.length >= _pageSize,
          currentPage: nextPage,
        ),
      );
    } catch (e) {
      // Silently fail for load more
    }
  }

  /// Fetch unread count only.
  Future<void> fetchUnreadCount() async {
    if (_userId == null) return;

    try {
      final count = await _notificationService.fetchUnreadCount(_userId!);
      emit(state.copyWith(unreadCount: count));
    } catch (e) {
      // Silently fail
    }
  }

  /// Fetch notification stats.
  Future<void> fetchStats() async {
    if (_userId == null) return;

    try {
      final stats = await _notificationService.fetchStats(_userId!);
      emit(state.copyWith(stats: stats));
    } catch (e) {
      // Silently fail
    }
  }

  /// Mark a notification as read.
  Future<void> markAsRead(String notificationId) async {
    if (_userId == null) return;

    // Optimistic update
    final updated = state.notifications.map((n) {
      if (n.id == notificationId && !n.isRead) {
        return n.copyWith(readAt: DateTime.now());
      }
      return n;
    }).toList();

    final wasUnread = state.notifications.any(
      (n) => n.id == notificationId && !n.isRead,
    );

    emit(
      state.copyWith(
        notifications: updated,
        unreadCount: wasUnread ? state.unreadCount - 1 : state.unreadCount,
      ),
    );

    // Send via WebSocket for speed
    _notificationService.markAsReadWs(notificationId);
  }

  /// Mark all notifications as read.
  Future<void> markAllAsRead() async {
    if (_userId == null) return;

    // Optimistic update
    final updated = state.notifications.map((n) {
      if (!n.isRead) {
        return n.copyWith(readAt: DateTime.now());
      }
      return n;
    }).toList();

    emit(state.copyWith(notifications: updated, unreadCount: 0));

    // Send via WebSocket for speed
    _notificationService.markAllAsReadWs();
  }

  /// Dismiss a notification.
  Future<void> dismiss(String notificationId) async {
    if (_userId == null) return;

    // Optimistic update - remove from list
    final wasUnread = state.notifications.any(
      (n) => n.id == notificationId && !n.isRead,
    );

    final updated = state.notifications
        .where((n) => n.id != notificationId)
        .toList();

    emit(
      state.copyWith(
        notifications: updated,
        unreadCount: wasUnread ? state.unreadCount - 1 : state.unreadCount,
      ),
    );

    // Send via WebSocket for speed
    _notificationService.dismissWs(notificationId);
  }

  /// Fetch notification preferences.
  Future<void> fetchPreferences() async {
    if (_userId == null) return;

    try {
      final preferences = await _notificationService.fetchPreferences(_userId!);
      emit(state.copyWith(preferences: preferences));
    } catch (e) {
      // Silently fail
    }
  }

  /// Update notification preferences.
  Future<void> updatePreferences(Map<String, dynamic> updates) async {
    if (_userId == null) return;

    try {
      final preferences = await _notificationService.updatePreferences(
        _userId!,
        updates,
      );
      emit(state.copyWith(preferences: preferences));
    } catch (e) {
      emit(
        state.copyWith(
          status: NotificationStatus.error,
          errorMessage: 'Failed to update preferences',
        ),
      );
    }
  }

  /// Send a test notification (for development).
  Future<void> sendTestNotification({
    String title = 'Test Notification',
    String body = 'This is a test notification.',
    NotificationType type = NotificationType.systemInfo,
  }) async {
    if (_userId == null) return;

    try {
      await _notificationService.sendTestNotification(
        userId: _userId!,
        title: title,
        body: body,
        type: type,
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: NotificationStatus.error,
          errorMessage: 'Failed to send test notification',
        ),
      );
    }
  }

  /// Disconnect and clean up.
  Future<void> disconnect() async {
    await _notificationSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _notificationService.disconnect();
    _userId = null;
  }

  @override
  Future<void> close() async {
    await disconnect();
    return super.close();
  }
}
