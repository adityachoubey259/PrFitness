import 'package:flutter_test/flutter_test.dart';
import 'package:prfitness/features/health/domain/health_engine.dart';

void main() {
  group('HealthEngine', () {
    test('moderate running estimate is deterministic', () {
      final ActivityEstimate result = HealthEngine.estimateActivity(
        activityType: 'Running',
        intensity: 'moderate',
        weightKg: 80,
        durationMinutes: 30,
      );

      expect(result.met, closeTo(9.3, 0.001));

      expect(result.calories, closeTo(390.6, 0.1));
    });

    test('faster walking increases estimated MET', () {
      final ActivityEstimate slow = HealthEngine.estimateActivity(
        activityType: 'Walking',
        intensity: 'moderate',
        weightKg: 80,
        durationMinutes: 60,
        distanceKm: 3,
      );

      final ActivityEstimate fast = HealthEngine.estimateActivity(
        activityType: 'Walking',
        intensity: 'moderate',
        weightKg: 80,
        durationMinutes: 60,
        distanceKm: 6,
      );

      expect(fast.met, greaterThan(slow.met));

      expect(fast.calories, greaterThan(slow.calories));
    });

    test('distance calculates speed correctly', () {
      final ActivityEstimate result = HealthEngine.estimateActivity(
        activityType: 'Cycling',
        intensity: 'moderate',
        weightKg: 70,
        durationMinutes: 30,
        distanceKm: 10,
      );

      expect(result.speedKmH, closeTo(20, 0.001));
    });
  });
}
