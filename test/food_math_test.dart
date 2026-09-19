import 'package:flutter_test/flutter_test.dart';
import 'package:prfitness/features/food/domain/food_math.dart';

void main() {
  test('per-100g nutrition scales accurately', () {
    final portion = FoodMath.fromPer100g(
      grams: 150,
      caloriesPer100g: 130,
      proteinPer100g: 2.7,
      carbsPer100g: 28.2,
      fatPer100g: 0.3,
    );
    expect(portion.calories, 195.0);
    expect(portion.proteinG, 4.1);
    expect(portion.carbsG, 42.3);
    expect(portion.fatG, 0.5);
  });

  test('invalid serving is rejected', () {
    expect(
      () => FoodMath.fromPer100g(
        grams: 0,
        caloriesPer100g: 100,
        proteinPer100g: 1,
        carbsPer100g: 1,
        fatPer100g: 1,
      ),
      throwsArgumentError,
    );
  });
}
