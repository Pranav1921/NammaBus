import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';

final _logger = Logger('NotificationService');

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Keep track of the app's lifecycle state
  bool _isAppInForeground = true;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) async {},
    );
    _logger.info('Notification service initialized.');
  }

  // Method to be called from a WidgetsBindingObserver
  void setAppInForeground(bool isForeground) {
    _isAppInForeground = isForeground;
    _logger.info('App foreground state updated: $_isAppInForeground');
  }

  // Shows a notification only if the app is in the background
  Future<void> showDestinationAlertNotification(String stopName) async {
    if (_isAppInForeground) {
      _logger.info('App is in the foreground; suppressing system notification.');
      return; // Don't show a notification if the app is active
    }

    _logger.info('App is in background. Sending destination alert notification.');
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'destination_alert_channel', // A specific channel for this type of alert
      'Destination Alerts',
      channelDescription: 'Notifications for when you are approaching your destination.',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      1, // Unique ID for destination alerts
      'Approaching Your Stop',
      'You are almost at $stopName.',
      platformChannelSpecifics,
    );
  }

  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'bus_tracker_channel',
      'Bus Tracker Notifications',
      channelDescription: 'Notifications for bus ETAs and alerts',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      0,
      'Test Notification',
      'This is a test notification from the Bus Tracker app.',
      platformChannelSpecifics,
    );
    _logger.info('Test notification sent.');
  }
}
