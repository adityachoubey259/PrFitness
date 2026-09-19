import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../database/app_database.dart';
import '../../features/reminders/domain/reminder_rules.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (!Platform.isAndroid) {
      _initialized = true;
      return;
    }

    tzdata.initializeTimeZones();

    try {
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();

      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }

    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_prfitness'),
    );

    await _plugin.initialize(settings: settings);

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();

    if (!Platform.isAndroid) {
      return false;
    }

    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<bool> notificationsEnabled() async {
    await initialize();

    if (!Platform.isAndroid) {
      return false;
    }

    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    return await android?.areNotificationsEnabled() ?? false;
  }

  Future<int> pendingCount() async {
    await initialize();

    if (!Platform.isAndroid) {
      return 0;
    }

    final List<PendingNotificationRequest> pending = await _plugin
        .pendingNotificationRequests();

    return pending.length;
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    await initialize();

    if (!Platform.isAndroid) {
      return;
    }

    await cancelReminder(reminder);

    if (!reminder.enabled) {
      return;
    }

    ReminderRules.validate(
      title: reminder.title,
      scheduleType: reminder.scheduleType,
      hour: reminder.hour,
      minute: reminder.minute,
      weekdaysMask: reminder.weekdaysMask,
      scheduledAt: reminder.scheduledAt,
    );

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'prfitness_reminders_v1',
        'PrFitness Reminders',
        channelDescription: 'Study, hydration, goals and routine reminders',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    );

    final String payload = 'reminder:${reminder.id}';

    if (reminder.scheduleType == 'one_time') {
      final DateTime source = reminder.scheduledAt!;

      final tz.TZDateTime scheduled = tz.TZDateTime(
        tz.local,
        source.year,
        source.month,
        source.day,
        source.hour,
        source.minute,
      );

      await _plugin.zonedSchedule(
        id: reminder.notificationBaseId,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );

      return;
    }

    if (reminder.scheduleType == 'daily') {
      await _plugin.zonedSchedule(
        id: reminder.notificationBaseId,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: _nextTime(reminder.hour, reminder.minute),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );

      return;
    }

    final List<int> weekdays = ReminderRules.daysFromMask(
      reminder.weekdaysMask,
    );

    for (final int weekday in weekdays) {
      await _plugin.zonedSchedule(
        id: reminder.notificationBaseId + weekday,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: _nextWeekday(
          weekday: weekday,
          hour: reminder.hour,
          minute: reminder.minute,
        ),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );
    }
  }

  Future<void> cancelReminder(Reminder reminder) async {
    await initialize();

    if (!Platform.isAndroid) {
      return;
    }

    await _plugin.cancel(id: reminder.notificationBaseId);

    for (int day = 1; day <= 7; day++) {
      await _plugin.cancel(id: reminder.notificationBaseId + day);
    }
  }

  tz.TZDateTime _nextTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  tz.TZDateTime _nextWeekday({
    required int weekday,
    required int hour,
    required int minute,
  }) {
    tz.TZDateTime candidate = _nextTime(hour, minute);

    while (candidate.weekday != weekday) {
      candidate = candidate.add(const Duration(days: 1));
    }

    return candidate;
  }
}
