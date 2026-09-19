import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../productivity/domain/performance_engine.dart';
import '../../profile/domain/body_metrics.dart';
import '../domain/analytics_engine.dart';

class AnalyticsRepository {
  AnalyticsRepository(this.database);

  final AppDatabase database;

  Future<AnalyticsSnapshot> load({
    required ProfileRow profile,
    int days = 30,
  }) async {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime start = today.subtract(Duration(days: days - 1));

    final DateTime end = today.add(const Duration(days: 1));

    final List<FoodEntry> foods =
        await (database.select(database.foodEntries)..where(
              (FoodEntries table) =>
                  table.occurredAt.isBiggerOrEqualValue(start) &
                  table.occurredAt.isSmallerThanValue(end),
            ))
            .get();

    final List<ActivityEntry> activities =
        await (database.select(database.activityEntries)..where(
              (ActivityEntries table) =>
                  table.occurredAt.isBiggerOrEqualValue(start) &
                  table.occurredAt.isSmallerThanValue(end),
            ))
            .get();

    final List<WaterEntry> waters =
        await (database.select(database.waterEntries)..where(
              (WaterEntries table) =>
                  table.occurredAt.isBiggerOrEqualValue(start) &
                  table.occurredAt.isSmallerThanValue(end),
            ))
            .get();

    final List<StudySession> study =
        await (database.select(database.studySessions)..where(
              (StudySessions table) =>
                  table.startedAt.isBiggerOrEqualValue(start) &
                  table.startedAt.isSmallerThanValue(end),
            ))
            .get();

    final List<Goal> goals = await (database.select(
      database.goals,
    )..where((Goals table) => table.active.equals(true))).get();

    final List<GoalCompletion> goalCompletions =
        await (database.select(database.goalCompletions)..where(
              (GoalCompletions table) =>
                  table.completedAt.isBiggerOrEqualValue(start) &
                  table.completedAt.isSmallerThanValue(end),
            ))
            .get();

    final List<RoutineItem> routines = await (database.select(
      database.routineItems,
    )..where((RoutineItems table) => table.active.equals(true))).get();

    final List<RoutineCompletion> routineCompletions =
        await (database.select(database.routineCompletions)..where(
              (RoutineCompletions table) =>
                  table.completedAt.isBiggerOrEqualValue(start) &
                  table.completedAt.isSmallerThanValue(end),
            ))
            .get();

    final Map<DateTime, _Accumulator> accumulator = <DateTime, _Accumulator>{
      for (int offset = 0; offset < days; offset++)
        start.add(Duration(days: offset)): _Accumulator(),
    };

    DateTime dateOnly(DateTime value) =>
        DateTime(value.year, value.month, value.day);

    for (final FoodEntry entry in foods) {
      accumulator[dateOnly(entry.occurredAt)]?.intake += entry.calories;
    }

    for (final ActivityEntry entry in activities) {
      accumulator[dateOnly(entry.occurredAt)]?.movement += entry.caloriesBurned;
    }

    for (final WaterEntry entry in waters) {
      accumulator[dateOnly(entry.occurredAt)]?.water += entry.amountMl;
    }

    for (final StudySession entry in study) {
      accumulator[dateOnly(entry.startedAt)]?.studySeconds +=
          entry.durationSeconds;
    }

    for (final GoalCompletion entry in goalCompletions) {
      accumulator[dateOnly(entry.completedAt)]?.goalIds.add(entry.goalId);
    }

    for (final RoutineCompletion entry in routineCompletions) {
      accumulator[dateOnly(entry.completedAt)]?.routineIds.add(entry.routineId);
    }

    final BodyMetricsSnapshot body = BodyMetrics.evaluate(
      birthDate: profile.birthDate,
      sex: profile.sex,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      activityLevel: profile.activityLevel,
      goal: profile.goal,
    );

    final List<DailySignal> signals = <DailySignal>[];

    for (final MapEntry<DateTime, _Accumulator> entry in accumulator.entries) {
      final _Accumulator value = entry.value;

      final int studyMinutes = (value.studySeconds / 60).floor();

      final PerformanceSnapshot performance = PerformanceEngine.evaluate(
        studyMinutes: studyMinutes,
        studyTargetMinutes: profile.dailyStudyTargetMinutes,
        waterMl: value.water,
        waterTargetMl: body.waterTargetMl,
        totalGoals: goals.length,
        completedGoals: value.goalIds.length,
        totalRoutines: routines.length,
        completedRoutines: value.routineIds.length,
      );

      signals.add(
        DailySignal(
          date: entry.key,
          studyMinutes: studyMinutes,
          waterMl: value.water,
          intakeCalories: value.intake,
          activityCalories: value.movement,
          goalCompletions: value.goalIds.length,
          routineCompletions: value.routineIds.length,
          score: performance.score,
          studyRatio: performance.studyRatio,
          hydrationRatio: performance.hydrationRatio,
          goalRatio: performance.goalRatio,
          routineRatio: performance.routineRatio,
        ),
      );
    }

    return AnalyticsEngine.summarize(signals);
  }
}

class _Accumulator {
  int studySeconds = 0;
  int water = 0;

  double intake = 0;
  double movement = 0;

  final Set<String> goalIds = <String>{};

  final Set<String> routineIds = <String>{};
}
