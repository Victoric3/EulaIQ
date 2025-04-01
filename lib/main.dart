import 'package:eulaiq/src/common/services/firebase_messaging_service.dart';
import 'package:eulaiq/src/common/services/session_expiration_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:eulaiq/src/app.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:eulaiq/src/common/utils/app_lifecycle_manager.dart';
import 'package:eulaiq/src/common/utils/memory_monitor.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

// Register a lifecycle observer to handle cleanup
class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // Clean up resources when app is closing
      SessionExpirationHandler.dispose();
    }
  }
}

void main() async {
  try {
    // Set error handling
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('Flutter error: ${details.exception}');
    };
    
    // Reset app state on start (helps with hot reload)
    WidgetsFlutterBinding.ensureInitialized();
    AppLifecycleManager.resetAppState();
    
    // Register the observer for lifecycle events
    WidgetsBinding.instance.addObserver(AppLifecycleObserver());
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Background message handler must be registered before initializing FCM
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Setup notification channel first
    await _setupNotificationChannel();
    
    final prefs = await SharedPreferences.getInstance();
    final messagingService = await FirebaseMessagingService.create();
    
    if (!kIsWeb) {
      await DioConfig.setupDio();
    }
    
    // Start memory monitoring in debug mode
    MemoryMonitor.startMonitoring();
    
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          firebaseMessagingServiceProvider.overrideWithValue(messagingService),
        ],
        child: MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    print('Startup error: $e');
    print('Stack trace: $stackTrace');
  }
}

Future<void> _setupNotificationChannel() async {
  const androidChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);
}
