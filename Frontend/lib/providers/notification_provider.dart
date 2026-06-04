import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get hasUnread => _unreadCount > 0;

  void clear() {
    _notifications = [];
    _unreadCount = 0;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> loadNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await ApiService.getNotifications();
      if (resp.success && resp.data != null) {
        _notifications = resp.data!;
        _unreadCount = _notifications.where((n) => !n.isRead).length;
      } else {
        _notifications = [];
        _unreadCount = 0;
        _error = resp.message.isNotEmpty
            ? resp.message
            : 'Khong the tai thong bao';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUnreadCount() async {
    try {
      final resp = await ApiService.getUnreadCount();
      if (resp.success) {
        _unreadCount = resp.data ?? 0;
        notifyListeners();
      } else if (resp.message.isNotEmpty) {
        _error = resp.message;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAsRead(int id) async {
    final resp = await ApiService.markNotificationRead(id);
    if (resp.success) {
      final idx = _notifications.indexWhere((n) => n.notificationId == id);
      if (idx != -1 && !_notifications[idx].isRead) {
        _notifications[idx] = AppNotification(
          notificationId: _notifications[idx].notificationId,
          accountId: _notifications[idx].accountId,
          title: _notifications[idx].title,
          message: _notifications[idx].message,
          type: _notifications[idx].type,
          isRead: true,
          createdOn: _notifications[idx].createdOn,
        );
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    }
  }

  Future<void> markAllAsRead() async {
    final resp = await ApiService.markAllNotificationsRead();
    if (resp.success) {
      _notifications = _notifications
          .map(
            (n) => AppNotification(
              notificationId: n.notificationId,
              accountId: n.accountId,
              title: n.title,
              message: n.message,
              type: n.type,
              isRead: true,
              createdOn: n.createdOn,
            ),
          )
          .toList();
      _unreadCount = 0;
      notifyListeners();
    }
  }

  Future<void> deleteNotification(int id) async {
    final resp = await ApiService.deleteNotification(id);
    if (resp.success) {
      _notifications.removeWhere((n) => n.notificationId == id);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }
  }

  void addLocalNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    if (!notification.isRead) {
      _unreadCount++;
    }
    notifyListeners();
  }
}
