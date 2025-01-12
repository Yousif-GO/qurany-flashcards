import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';

class NotificationService {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tzdata.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (status != PermissionStatus.granted) {
        await showPermissionDialog();
      }
    }
  }

  Future<void> showPermissionDialog() async {
    return showDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Notifications Permission'),
          content: const Text(
            'Please enable notifications in settings to receive reminders.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> scheduleReviewNotification(
      int pageNumber, int ayahNumber, DateTime reviewTime) async {
    final notificationId = _generateUniqueId(pageNumber, ayahNumber);

    // Configure notification details
    final androidDetails = AndroidNotificationDetails(
      'srs_reviews',
      'SRS Reviews',
      channelDescription: 'Notifications for Quran review schedule',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      actions: [
        AndroidNotificationAction('review', 'Review Now'),
        AndroidNotificationAction('later', 'Later'),
      ],
    );

    await notifications.zonedSchedule(
      notificationId,
      'Review Time',
      'Time to review Page $pageNumber, Ayah $ayahNumber',
      tz.TZDateTime.from(reviewTime, tz.local),
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  int _generateUniqueId(int pageNumber, int ayahNumber) {
    return pageNumber.hashCode ^ ayahNumber.hashCode;
  }
}
