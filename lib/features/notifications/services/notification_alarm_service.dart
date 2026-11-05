import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final notificationAlarmServiceProvider = Provider<NotificationAlarmService>((ref) {
  return NotificationAlarmService();
});

class NotificationAlarmService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'medwise_intake_channel';
  static const String channelName = 'Medicine Intake Reminders';
  static const String channelDescription =
      'Exact alarms for daily medicine dosages and antibiotic adherence.';

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationAction,
    );

    // Create high-importance Android notification channel
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('notification'),
          enableVibration: true,
        ),
      );
    }
  }

  void _onNotificationAction(NotificationResponse response) {
    debugPrint('Notification clicked / action selected: ${response.actionId}');
  }

  /// Schedule a daily exact dose alarm for a specific time of day (e.g. "08:30")
  Future<void> scheduleDoseAlarm({
    required int id,
    required String medicineName,
    required String doseAmount,
    required String mealRelation,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the scheduled time has already passed today, advance to tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'MARK_TAKEN',
          'Mark Taken',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'SNOOZE_15',
          'Snooze 15m',
        ),
      ],
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      'Time for your dose: $medicineName',
      'Take $doseAmount ($mealRelation)',
      scheduledDate,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelAlarm(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
