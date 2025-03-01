import 'package:eulaiq/src/common/services/firebase_messaging_service.dart';
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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
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
    
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          firebaseMessagingServiceProvider.overrideWithValue(messagingService),
        ],
        child: const MyApp(),
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
