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
    WidgetsFlutterBinding.ensureInitialized();
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Setup notification channel first
    await _setupNotificationChannel();
    
    final prefs = await SharedPreferences.getInstance();
    
    // Try to initialize messaging service but continue if it fails
    FirebaseMessagingService? messagingService;
    try {
      messagingService = await FirebaseMessagingService.create();
    } catch (e) {
      print('Warning: Firebase messaging initialization failed: $e');
      // Continue without messaging service
    }
    
    if (!kIsWeb) {
      await DioConfig.setupDio();
    }
    
    // Start memory monitoring in debug mode
    MemoryMonitor.startMonitoring();
    
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (messagingService != null)
            firebaseMessagingServiceProvider.overrideWithValue(messagingService),
        ],
        child: MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    print('Startup error: $e');
    print('Stack trace: $stackTrace');
    
    // Run a minimal app even if initialization fails
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Text('App initialization failed')),
      ),
    ));
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
