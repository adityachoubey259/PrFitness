import 'package:flutter_test/flutter_test.dart';
import 'package:prfitness/features/analytics/domain/analytics_engine.dart';

void main() {
  group('AnalyticsEngine', () {
    test('detects consecutive target streaks', () {
      final List<DailySignal> days = List<DailySignal>.generate(
        5,
        (int index) => DailySignal(
          date: DateTime(2026, 9, 15 + index),
          studyMinutes: 120,
          waterMl: 2800,
          intakeCalories: 2000,
          activityCalories: 300,
          goalCompletions: 2,
          routineCompletions: 2,
          score: 100,
          studyRatio: 1,
          hydrationRatio: 1,
          goalRatio: 1,
          routineRatio: 1,
        ),
      );

      final AnalyticsSnapshot result = AnalyticsEngine.summarize(days);

      expect(result.studyStreak, 5);

      expect(result.hydrationStreak, 5);

      expect(result.averageConsistency7, 100);
    });

    test('finds best study day', () {
      final AnalyticsSnapshot result = AnalyticsEngine.summarize(<DailySignal>[
        DailySignal(
          date: DateTime(2026, 9, 18),
          studyMinutes: 60,
          waterMl: 1000,
          intakeCalories: 0,
          activityCalories: 0,
          goalCompletions: 0,
          routineCompletions: 0,
          score: 40,
          studyRatio: 0.5,
          hydrationRatio: 0.4,
        ),
        DailySignal(
          date: DateTime(2026, 9, 19),
          studyMinutes: 180,
          waterMl: 2800,
          intakeCalories: 0,
          activityCalories: 500,
          goalCompletions: 0,
          routineCompletions: 0,
          score: 100,
          studyRatio: 1,
          hydrationRatio: 1,
        ),
      ]);

      expect(result.bestStudyMinutes, 180);

      expect(result.activityCalories30, 500);
    });

    test('does not fabricate insight when no activity exists', () {
      final AnalyticsSnapshot result = AnalyticsEngine.summarize(<DailySignal>[
        DailySignal(
          date: DateTime(2026, 9, 19),
          studyMinutes: 0,
          waterMl: 0,
          intakeCalories: 0,
          activityCalories: 0,
          goalCompletions: 0,
          routineCompletions: 0,
          score: 0,
          studyRatio: 0,
          hydrationRatio: 0,
        ),
      ]);

      expect(result.headline, 'Signal building');
    });
  });
}
