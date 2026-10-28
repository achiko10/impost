import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  AppUser? currentUser;
  bool isInitializing = true;
  bool isLoading = false;
  int unreadNotifications = 0;
  List<AppNotification> notifications = [];

  Future<void> initialize() async {
    isInitializing = true;
    notifyListeners();
    try {
      await ApiService.init();
      if (ApiService.accessToken != null && ApiService.accessToken!.isNotEmpty) {
        currentUser = await ApiService.getProfile();
        await refreshNotifications();
      }
    } catch (_) {
      await ApiService.clearTokens();
      currentUser = null;
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    isLoading = true;
    notifyListeners();
    try {
      currentUser = await ApiService.login(username, password);
      await refreshNotifications();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signup({
    required String companyName,
    required String username,
    required String password,
    String firstName = '',
    String lastName = '',
    String phone = '',
  }) async {
    isLoading = true;
    notifyListeners();
    try {
      currentUser = await ApiService.signup(
        companyName: companyName,
        username: username,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );
      await refreshNotifications();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await ApiService.logout();
    currentUser = null;
    unreadNotifications = 0;
    notifications = [];
    notifyListeners();
  }

  Future<void> refreshNotifications() async {
    if (currentUser == null) return;
    try {
      final res = await ApiService.getNotifications();
      unreadNotifications = res['unread_count'] ?? 0;
      notifications =
          (res['notifications'] as List<AppNotification>? ?? <AppNotification>[]);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    await ApiService.markAllNotificationsRead();
    await refreshNotifications();
  }

  Future<void> markRead(int id) async {
    await ApiService.markNotificationRead(id);
    await refreshNotifications();
  }

  Future<void> deleteNotification(int id) async {
    await ApiService.deleteNotification(id);
    await refreshNotifications();
  }
}
