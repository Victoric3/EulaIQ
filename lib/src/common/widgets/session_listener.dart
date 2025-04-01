import 'dart:async';

import 'package:eulaiq/src/common/router/app_router_instance.dart'; // Add this import
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eulaiq/src/common/services/session_expiration_handler.dart';

import 'notification_card.dart';

class SessionListener extends ConsumerStatefulWidget {
  final Widget child;
  
  const SessionListener({
    Key? key,
    required this.child,
  }) : super(key: key);
  
  @override
  ConsumerState<SessionListener> createState() => _SessionListenerState();
}

class _SessionListenerState extends ConsumerState<SessionListener> {
  StreamSubscription? _subscription;
  
  @override
  void initState() {
    super.initState();
    
    // Set up the listener after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSessionListener();
    });
  }
  
  void _setupSessionListener() {
    // Listen for session expiration events
    _subscription = ref.read(sessionExpiredStreamProvider).listen((_) {
      print("Session expired event received!");
      
      // Wait for the next frame to ensure we have a valid context
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Handle session expiration
          SessionExpirationHandler.handleExpiredSession(ref, context);
        } else {
          // Use a direct navigation approach instead of private method
          _handleFallbackNavigation();
        }
      });
    });
  }
  
  // Add this method to handle fallback navigation
  void _handleFallbackNavigation() {
    print('🔴 Using fallback navigation to login screen');
    try {
      // Use the singleton router instance instead of appRouterKey
      final router = AppRouterInstance.getRouter();
      if (router != null) {
        AppRouterInstance.navigateToIntro();
        print('🔴 Navigation successful via AppRouterInstance');
      } else {
        // If still no router, show a notification that will persist
        print('🔴 No router instance available, showing notification');
        NotificationService().showNotification(
          message: 'Session expired. Please restart the app.',
          type: NotificationType.error,
          duration: const Duration(seconds: 10),
        );
      }
    } catch (e) {
      print('🔴 Navigation error: $e');
      // Also show notification on error
      NotificationService().showNotification(
        message: 'Session expired. Please restart the app.',
        type: NotificationType.error,
        duration: const Duration(seconds: 10),
      );
    }
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}