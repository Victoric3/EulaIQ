// import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  String? fcmToken;

  static Future<FirebaseMessagingService> create() async {
    final service = FirebaseMessagingService();
    await service.initialize();
    return service;
  }

  Future<void> initialize() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('User granted provisional permission');
      }

      try {
        // Initialize local notifications with error handling
        const initializationSettingsAndroid = AndroidInitializationSettings('@drawable/notification_icon');
        const initializationSettingsIOS = DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );
        const initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

        await _localNotifications.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );
      } catch (e) {
        print('Failed to initialize local notifications: $e');
        // Continue with app initialization even if notifications fail
      }

      // Get FCM token
      fcmToken = await _firebaseMessaging.getToken();
      print('FCM Token: $fcmToken');

      // Set up message handlers
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage).onError((error) {
        print('Error handling foreground message: $error');
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp).onError((error) {
        print('Error handling opened app message: $error');
      });

      // Check for initial message
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleInitialMessage(initialMessage);
      }

      // Set foreground notification presentation options
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

    } catch (e) {
      print('Firebase Messaging initialization error: $e');
      // Don't rethrow here to prevent app crashes
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      await _showLocalNotification(message);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Message opened app: ${message.data}');
    // Add your navigation logic here
  }

  void _handleInitialMessage(RemoteMessage message) {
    print('Initial message: ${message.data}');
    // Add your navigation logic here
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // Add your navigation logic here
  }

  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }

  // Future<void> _updateTokenInBackend(String token) async {
  //   try {
  //     final response = await DioConfig.dio?.put(
  //       '/users/devices/token',
  //       data: {'fcmToken': token},
  //     );

  //     if (response?.statusCode == 200) {
  //       print('FCM token updated in backend');
  //     }
  //   } catch (e) {
  //     print('Failed to update FCM token in backend: $e');
  //   }
  // }
}

final firebaseMessagingServiceProvider = Provider<FirebaseMessagingService>((ref) {
  throw UnimplementedError();
});