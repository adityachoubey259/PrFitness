import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/id_factory.dart';
import '../domain/reminder_rules.dart';

class ReminderRepository {
  ReminderRepository(this.database, {NotificationService? notificationService})
    : notificationService = notificationService ?? NotificationService.instance;

  final AppDatabase database;
  final NotificationService notificationService;

  Future<Reminder> create({
    required String title,
    required String body,
    required String category,
    required String scheduleType,
    required int hour,
    required int minute,
    required int weekdaysMask,
    DateTime? scheduledAt,
  }) async {
    ReminderRules.validate(
      title: title,
      scheduleType: scheduleType,
      hour: hour,
      minute: minute,
      weekdaysMask: weekdaysMask,
      scheduledAt: scheduledAt,
    );

    final String id = IdFactory.uuidV4();

    final DateTime now = DateTime.now();

    final int notificationBaseId = _notificationBaseId(id);

    await database.upsertReminder(
      RemindersCompanion.insert(
        id: id,
        title: title.trim(),
        body: Value(
          body.trim().isEmpty ? 'Time to make progress.' : body.trim(),
        ),
        category: Value(category),
        scheduleType: Value(scheduleType),
        hour: hour,
        minute: minute,
        weekdaysMask: Value(weekdaysMask),
        scheduledAt: Value(scheduledAt),
        notificationBaseId: notificationBaseId,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final Reminder? reminder = await database.getReminder(id);

    if (reminder == null) {
      throw StateError('Reminder could not be reloaded.');
    }

    await notificationService.scheduleReminder(reminder);

    return reminder;
  }

  Future<void> setEnabled({
    required Reminder reminder,
    required bool enabled,
  }) async {
    await (database.update(
      database.reminders,
    )..where((Reminders table) => table.id.equals(reminder.id))).write(
      RemindersCompanion(
        enabled: Value(enabled),
        updatedAt: Value(DateTime.now()),
      ),
    );

    final Reminder? updated = await database.getReminder(reminder.id);

    if (updated == null) {
      return;
    }

    if (enabled) {
      await notificationService.scheduleReminder(updated);
    } else {
      await notificationService.cancelReminder(updated);
    }
  }

  Future<void> delete(Reminder reminder) async {
    await notificationService.cancelReminder(reminder);

    await database.deleteReminder(reminder.id);
  }

  Future<void> rescheduleEnabledReminders() async {
    final List<Reminder> reminders = await database.getReminders();

    for (final Reminder reminder in reminders) {
      if (reminder.enabled) {
        try {
          await notificationService.scheduleReminder(reminder);
        } catch (_) {
          // The app remains functional even when
          // the OS rejects a notification schedule.
        }
      }
    }
  }

  int _notificationBaseId(String id) {
    int hash = 17;

    for (final int unit in id.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }

    return 100000 + (hash % 100000000);
  }
}
