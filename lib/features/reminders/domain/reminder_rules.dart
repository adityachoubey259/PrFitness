abstract final class ReminderRules {
  static int maskFromDays(Iterable<int> weekdays) {
    int mask = 0;

    for (final int day in weekdays) {
      if (day < 1 || day > 7) {
        throw ArgumentError('Weekday must be between 1 and 7.');
      }

      mask |= 1 << (day - 1);
    }

    return mask;
  }

  static List<int> daysFromMask(int mask) {
    return <int>[
      for (int day = 1; day <= 7; day++)
        if ((mask & (1 << (day - 1))) != 0) day,
    ];
  }

  static void validate({
    required String title,
    required String scheduleType,
    required int hour,
    required int minute,
    required int weekdaysMask,
    DateTime? scheduledAt,
    DateTime? now,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError('Reminder title is required.');
    }

    if (hour < 0 || hour > 23) {
      throw ArgumentError('Hour must be between 0 and 23.');
    }

    if (minute < 0 || minute > 59) {
      throw ArgumentError('Minute must be between 0 and 59.');
    }

    if (scheduleType != 'daily' &&
        scheduleType != 'weekdays' &&
        scheduleType != 'one_time') {
      throw ArgumentError('Unsupported reminder schedule.');
    }

    if (scheduleType == 'weekdays' && weekdaysMask == 0) {
      throw ArgumentError('Select at least one weekday.');
    }

    if (scheduleType == 'one_time') {
      if (scheduledAt == null) {
        throw ArgumentError('One-time reminder requires a date.');
      }

      final DateTime reference = now ?? DateTime.now();

      if (!scheduledAt.isAfter(reference)) {
        throw ArgumentError('One-time reminder must be in the future.');
      }
    }
  }
}
