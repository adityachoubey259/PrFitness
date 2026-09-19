class FoodPortion {
  const FoodPortion({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.grams,
  });

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double grams;
}

class FoodMath {
  const FoodMath._();

  static FoodPortion fromPer100g({
    required double grams,
    required double caloriesPer100g,
    required double proteinPer100g,
    required double carbsPer100g,
    required double fatPer100g,
  }) {
    if (!grams.isFinite || grams <= 0 || grams > 5000) {
      throw ArgumentError('Serving grams must be > 0 and <= 5000.');
    }
    for (final value in <double>[
      caloriesPer100g,
      proteinPer100g,
      carbsPer100g,
      fatPer100g,
    ]) {
      if (!value.isFinite || value < 0) {
        throw ArgumentError(
          'Nutrition values must be finite and non-negative.',
        );
      }
    }

    final factor = grams / 100.0;
    double r1(double v) => (v * 10).roundToDouble() / 10.0;

    return FoodPortion(
      calories: r1(caloriesPer100g * factor),
      proteinG: r1(proteinPer100g * factor),
      carbsG: r1(carbsPer100g * factor),
      fatG: r1(fatPer100g * factor),
      grams: r1(grams),
    );
  }
}
