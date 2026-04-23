import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Must be top-level function — handles background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message: ${message.notification?.title}');
  // No need to show notification here — FCM handles it automatically
  // when app is in background/terminated
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _db        = FirebaseFirestore.instance;

  // Local notifications plugin (for foreground messages)
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Called once from main.dart after Firebase.initializeApp()
  Future<void> initialize() async {
    // Set background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission (shows popup on iOS, silent on Android 12 and below)
    final settings = await _messaging.requestPermission(
      alert:       true,
      badge:       true,
      sound:       true,
      provisional: false,
    );

    debugPrint('📬 FCM permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('📬 FCM permission denied — notifications will not work');
      return;
    }

    // Initialize local notifications for foreground display
    await _initLocalNotifications();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📬 App opened from notification: ${initialMessage.data}');
    }

    // Save token to Firestore
    await saveFcmToken();

    // Listen for token refreshes
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('📬 FCM token refreshed');
      _saveTokenToFirestore(newToken);
    });
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('📬 Local notification tapped: ${details.payload}');
      },
    );

    // Create the notification channel for Android
    const channel = AndroidNotificationChannel(
      'college_notices',        // Must match AndroidManifest.xml
      'College Notices',
      description: 'Notifications for new college notices',
      importance: Importance.high,
      playSound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Foreground message: ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    // Show local notification since FCM doesn't auto-show in foreground
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'college_notices',
          'College Notices',
          channelDescription: 'Notifications for new college notices',
          importance: Importance.high,
          priority:   Priority.high,
          icon:       '@mipmap/ic_launcher',
          playSound:  true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['noticeId'],
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('📬 Notification tapped: ${message.data}');
    // You can navigate to specific notice here if needed
    // Use a global navigator key for navigation outside widget tree
  }

  /// Save FCM token to current user's Firestore document
  Future<void> saveFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('📬 No user logged in — skipping token save');
      return;
    }

    try {
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('📬 Could not get FCM token');
        return;
      }

      await _saveTokenToFirestore(token);
    } catch (e) {
      debugPrint('📬 Error saving FCM token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).update({
      'fcmToken':        token,
      'fcmTokenUpdated': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ FCM token saved for ${user.email}');
  }

  /// Call this on sign out to remove the token
  Future<void> clearFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).update({
      'fcmToken': FieldValue.delete(),
    });
    await _messaging.deleteToken();
    debugPrint('📬 FCM token cleared');
  }
}