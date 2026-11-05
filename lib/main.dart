


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/database/bundled_db_helper.dart';
import 'core/database/cabinet_db_helper.dart';
import 'features/notifications/services/notification_alarm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Notifications and Alarms
  try {
    final notificationService = NotificationAlarmService();
    await notificationService.initialize();
  } catch (e) {
    debugPrint('Notification service initialization note: $e');
  }

  // Pre-initialize databases
  try {
    await BundledDbHelper.instance.database;
    await CabinetDbHelper.instance.database;
  } catch (e) {
    debugPrint('Database initialization note: $e');
  }

  runApp(
    const ProviderScope(
      child: MedWiseApp(),
    ),
  );
}
