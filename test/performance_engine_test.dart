import 'package:flutter_test/flutter_test.dart';
import 'package:prfitness/features/productivity/domain/performance_engine.dart';

void main() {
  group('PerformanceEngine', () {
    test('perfect adherence produces 100', () {
      final PerformanceSnapshot value = PerformanceEngine.evaluate(
        studyMinutes: 120,
        studyTargetMinutes: 120,
        waterMl: 2800,
        waterTargetMl: 2800,
        totalGoals: 4,
        completedGoals: 4,
        totalRoutines: 5,
        completedRoutines: 5,
      );

      expect(value.score, 100);
    });

    test('missing optional goals does not create fake failure', () {
      final PerformanceSnapshot value = PerformanceEngine.evaluate(
        studyMinutes: 120,
        studyTargetMinutes: 120,
        waterMl: 2800,
        waterTargetMl: 2800,
        totalGoals: 0,
        completedGoals: 0,
        totalRoutines: 0,
        completedRoutines: 0,
      );

      expect(value.score, 100);
      expect(value.goalRatio, isNull);
      expect(value.routineRatio, isNull);
    });

    test('weakest category becomes focus area', () {
      final PerformanceSnapshot value = PerformanceEngine.evaluate(
        studyMinutes: 30,
        studyTargetMinutes: 120,
        waterMl: 2800,
        waterTargetMl: 2800,
        totalGoals: 4,
        completedGoals: 4,
        totalRoutines: 4,
        completedRoutines: 4,
      );

      expect(value.focusArea, 'Study target');
    });
  });
}
