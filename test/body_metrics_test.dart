import 'package:flutter_test/flutter_test.dart';
import 'package:prfitness/features/profile/domain/body_metrics.dart';

void main() {
  group('BodyMetrics', () {
    test('calculates adult male Mifflin-St Jeor baseline', () {
      final BodyMetricsSnapshot result = BodyMetrics.evaluate(
        birthDate: DateTime(1996, 1, 1),
        sex: 'male',
        heightCm: 180,
        weightKg: 80,
        activityLevel: 'moderate',
        goal: 'maintain',
        asOf: DateTime(2026, 2, 1),
      );

      expect(result.age, 30);

      expect(result.bmr, closeTo(1780, 0.01));

      expect(result.bmi, closeTo(24.691, 0.01));

      expect(result.maintenanceCalories, closeTo(2759, 0.1));

      expect(result.waterTargetMl, 2800);
    });

    test('calculates female equation constant correctly', () {
      final double value = BodyMetrics.bmrMifflinStJeor(
        sex: 'female',
        age: 30,
        weightKg: 80,
        heightCm: 180,
      );

      expect(value, closeTo(1614, 0.01));
    });
  });
}
