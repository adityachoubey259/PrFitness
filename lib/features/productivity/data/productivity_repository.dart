import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_factory.dart';

class ProductivityRepository {
  ProductivityRepository(this.database);

  final AppDatabase database;

  Future<void> addStudySession({
    required String subject,
    required DateTime startedAt,
    required DateTime endedAt,
    String? notes,
  }) async {
    if (subject.trim().isEmpty) {
      throw ArgumentError('Subject is required.');
    }

    final int seconds = endedAt.difference(startedAt).inSeconds;

    if (seconds <= 0) {
      throw ArgumentError('Study duration must be positive.');
    }

    await database.addStudySession(
      StudySessionsCompanion.insert(
        id: IdFactory.uuidV4(),
        subject: subject.trim(),
        startedAt: startedAt,
        endedAt: endedAt,
        durationSeconds: seconds,
        notes: Value(notes?.trim().isEmpty ?? true ? null : notes!.trim()),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> addManualStudy({
    required String subject,
    required int minutes,
  }) async {
    if (minutes <= 0) {
      throw ArgumentError('Minutes must be positive.');
    }

    final DateTime end = DateTime.now();

    await addStudySession(
      subject: subject,
      startedAt: end.subtract(Duration(minutes: minutes)),
      endedAt: end,
    );
  }

  Future<void> addGoal({
    required String title,
    required String category,
  }) async {
    if (title.trim().isEmpty) {
      throw ArgumentError('Goal title is required.');
    }

    final DateTime now = DateTime.now();

    await database.addGoal(
      GoalsCompanion.insert(
        id: IdFactory.uuidV4(),
        title: title.trim(),
        category: Value(category),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> setGoalCompletedToday({
    required String goalId,
    required bool completed,
  }) async {
    final DateTime now = DateTime.now();

    final DateTime start = DateTime(now.year, now.month, now.day);

    final DateTime end = start.add(const Duration(days: 1));

    if (completed) {
      final GoalCompletion? existing =
          await (database.select(database.goalCompletions)
                ..where(
                  (GoalCompletions table) =>
                      table.goalId.equals(goalId) &
                      table.completedAt.isBiggerOrEqualValue(start) &
                      table.completedAt.isSmallerThanValue(end),
                )
                ..limit(1))
              .getSingleOrNull();

      if (existing == null) {
        await database
            .into(database.goalCompletions)
            .insert(
              GoalCompletionsCompanion.insert(
                id: IdFactory.uuidV4(),
                goalId: goalId,
                completedAt: now,
              ),
            );
      }
    } else {
      await (database.delete(database.goalCompletions)..where(
            (GoalCompletions table) =>
                table.goalId.equals(goalId) &
                table.completedAt.isBiggerOrEqualValue(start) &
                table.completedAt.isSmallerThanValue(end),
          ))
          .go();
    }
  }

  Future<void> addRoutine({required String title, required String type}) async {
    if (title.trim().isEmpty) {
      throw ArgumentError('Routine title is required.');
    }

    final DateTime now = DateTime.now();

    final int count = await database.routineItems.count().getSingle();

    await database.addRoutine(
      RoutineItemsCompanion.insert(
        id: IdFactory.uuidV4(),
        title: title.trim(),
        routineType: Value(type),
        sortOrder: Value(count),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> setRoutineCompletedToday({
    required String routineId,
    required bool completed,
  }) async {
    final DateTime now = DateTime.now();

    final DateTime start = DateTime(now.year, now.month, now.day);

    final DateTime end = start.add(const Duration(days: 1));

    if (completed) {
      final RoutineCompletion? existing =
          await (database.select(database.routineCompletions)
                ..where(
                  (RoutineCompletions table) =>
                      table.routineId.equals(routineId) &
                      table.completedAt.isBiggerOrEqualValue(start) &
                      table.completedAt.isSmallerThanValue(end),
                )
                ..limit(1))
              .getSingleOrNull();

      if (existing == null) {
        await database
            .into(database.routineCompletions)
            .insert(
              RoutineCompletionsCompanion.insert(
                id: IdFactory.uuidV4(),
                routineId: routineId,
                completedAt: now,
              ),
            );
      }
    } else {
      await (database.delete(database.routineCompletions)..where(
            (RoutineCompletions table) =>
                table.routineId.equals(routineId) &
                table.completedAt.isBiggerOrEqualValue(start) &
                table.completedAt.isSmallerThanValue(end),
          ))
          .go();
    }
  }
}
