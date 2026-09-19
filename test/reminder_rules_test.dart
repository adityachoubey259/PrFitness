import 'package:flutter_test/flutter_test.dart';
import 'package:prfitness/features/reminders/domain/reminder_rules.dart';

void main() {
  group('ReminderRules', () {
    test('weekday mask round-trips correctly', () {
      final int mask = ReminderRules.maskFromDays(<int>[1, 3, 5, 7]);

      expect(ReminderRules.daysFromMask(mask), <int>[1, 3, 5, 7]);
    });

    test('rejects empty custom weekday selection', () {
      expect(
        () => ReminderRules.validate(
          title: 'Study',
          scheduleType: 'weekdays',
          hour: 18,
          minute: 30,
          weekdaysMask: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects past one-time reminder', () {
      final DateTime now = DateTime(2026, 9, 19, 12);

      expect(
        () => ReminderRules.validate(
          title: 'Test',
          scheduleType: 'one_time',
          hour: 11,
          minute: 0,
          weekdaysMask: 127,
          scheduledAt: DateTime(2026, 9, 19, 11),
          now: now,
        ),
        throwsArgumentError,
      );
    });
  });
}
