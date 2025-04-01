import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:eulaiq/src/common/widgets/notification_card.dart';
import 'package:eulaiq/src/common/services/navigation_service.dart';

// Stream controller for session expiration events
final _sessionExpiredStreamController = StreamController<void>.broadcast();

// Provider for the session expiration stream
final sessionExpiredStreamProvider = Provider<Stream<void>>((ref) {
  return _sessionExpiredStreamController.stream;
});

class SessionExpirationHandler {
  // Static method to notify about session expiration
  static void notifySessionExpired() {
        _sessionExpiredStreamController.add(null);
  }
  
  // Method to handle session expiration
  static void handleExpiredSession(
    WidgetRef ref,
    BuildContext context,
  ) async {
    // Always check if we have a valid context
    if (!context.mounted) {
      _handleFallbackNavigation();
      return;
    }

    // Use a safer navigation approach
    final notificationService = ref.read(notificationServiceProvider);
    notificationService.showNotification(
      message: 'Your session has expired. Please sign in again.',
      type: NotificationType.warning,
      duration: const Duration(seconds: 5),
    );
    
    // Use the navigation service
    NavigationService.navigateToIntro();
  }

  static void _handleFallbackNavigation() {
    NavigationService.navigateToIntro();
  }

  // Dispose method to clean up resources
  static void dispose() {
    if (!_sessionExpiredStreamController.isClosed) {
      _sessionExpiredStreamController.close();
    }
  }
}