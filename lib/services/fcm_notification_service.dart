import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FCMNotificationService {
  static const String _streakChannelId = 'streak_notifications';
  static const String _streakChannelName = 'Streak Reminders';
  static const String _streakChannelDescription =
      'Notifications to help maintain your walking streak';

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  // Initialize the service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Tapping any local notification will bring the app to foreground.
        // Additional navigation can be added here if needed using response.payload
      },
    );

    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _streakChannelId,
      _streakChannelName,
      description: _streakChannelDescription,
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Set up FCM message handlers
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    _isInitialized = true;
    print('FCM notification service initialized');
  }

  // Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.messageId}');

    if (message.notification != null) {
      _showLocalNotification(
        message.notification!.title ?? 'Walkzilla',
        message.notification!.body ?? '',
        message.data['type'] ?? 'general',
      );
    }
  }

  // Handle background messages
  static void _handleBackgroundMessage(RemoteMessage message) {
    print('Received background message: ${message.messageId}');

    if (message.notification != null) {
      _showLocalNotification(
        message.notification!.title ?? 'Walkzilla',
        message.notification!.body ?? '',
        message.data['type'] ?? 'general',
      );
    }
  }

  // Show local notification
  static Future<void> _showLocalNotification(
      String title, String body, String type) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _streakChannelId,
      _streakChannelName,
      channelDescription: _streakChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    // Use different notification IDs for each type
    int notificationId;
    switch (type) {
      case 'final':
        notificationId = 1003;
        break;
      case 'daily_fact':
        notificationId = 1005;
        break;
      default:
        notificationId = 1004;
    }

    await _notifications.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: type,
    );
  }

  // Save FCM token to user document
  static Future<void> saveFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': fcmToken});

        print('FCM token saved to user document');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Request notification permissions
  static Future<void> requestPermissions() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('Notification permissions granted');
        await saveFCMToken();
      } else {
        print('Notification permissions denied');
      }
    } catch (e) {
      print('Error requesting notification permissions: $e');
    }
  }

  // Clear FCM token on logout and remove server-side token
  static Future<void> clearFCMTokenOnLogout() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      // Delete device token so a fresh one is issued next login
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (e) {
        // Best-effort; continue to clear Firestore
      }

      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': null});
      }
      print('FCM token cleared on logout');
    } catch (e) {
      print('Error clearing FCM token on logout: $e');
    }
  }
}
