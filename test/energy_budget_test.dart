import 'package:flutter_test/flutter_test.dart';
import 'package:prfitness/features/health/domain/energy_budget.dart';

void main() {
  test('logged exercise never increases the food budget', () {
    const withoutExercise = EnergyBudget(
      baselineTargetKcal: 2200,
      intakeKcal: 1700,
      loggedActivityKcal: 0,
    );
    const withExercise = EnergyBudget(
      baselineTargetKcal: 2200,
      intakeKcal: 1700,
      loggedActivityKcal: 700,
    );

    expect(withoutExercise.remainingKcal, 500);
    expect(withExercise.remainingKcal, 500);
    expect(withExercise.intakeProgress, closeTo(1700 / 2200, 0.0001));
    expect(withExercise.informationalNetAfterLoggedActivity, 1000);
  });

  test('remaining calories may become negative after overeating', () {
    const budget = EnergyBudget(
      baselineTargetKcal: 2000,
      intakeKcal: 2400,
      loggedActivityKcal: 900,
    );
    expect(budget.remainingKcal, -400);
  });
}
