import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/router/app_router.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';

import '../widgets/notification_card.dart';

/// A service that handles navigation throughout the app
/// with fallbacks and safety checks
class NavigationService {
  // Keep this static variable for compatibility, but don't use it with MaterialApp.router
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static StackRouter? _router;
  
  /// Set the app router instance
  static void setRouter(StackRouter router) {
    _router = router;
  }
  
  /// Get the current router instance
  static StackRouter? getRouter() {
    return _router;
  }
  
  /// Navigate to a route safely
  static Future<bool> navigateTo(PageRouteInfo route) async {
    try {
      if (_router != null) {
        await _router!.push(route);
        return true;
      } else if (navigatorKey.currentState != null) {
        // Fallback to navigator key
        await navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => const Text('Route not found')),
        );
        return true;
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      NotificationService().showNotification(
        message: 'Navigation error. Please try again.',
        type: NotificationType.error,
      );
    }
    return false;
  }
  
  /// Replace all routes with a new one
  static Future<bool> replaceAllWith(PageRouteInfo route) async {
    try {
      if (_router != null) {
        await _router!.replaceAll([route]);
        return true;
      } else if (navigatorKey.currentState != null) {
        // Fallback to navigator key
        navigatorKey.currentState!.pushNamedAndRemoveUntil(
          '/', (route) => false,
        );
        return true;
      }
    } catch (e) {
      debugPrint('Navigation replace error: $e');
      NotificationService().showNotification(
        message: 'Navigation error. Please try again.',
        type: NotificationType.error,
      );
    }
    return false;
  }
  
  /// Navigate to intro/login screen
  static Future<bool> navigateToIntro() async {
    try {
      if (_router != null) {
        await _router!.replaceAll([const IntroRoute()]);
        return true;
      }
    } catch (e) {
      print('Navigation error: $e');
    }
    return false;
  }
}