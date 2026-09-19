class BodyMetricsSnapshot {
  const BodyMetricsSnapshot({
    required this.age,
    required this.bmi,
    required this.bmiBand,
    required this.bmr,
    required this.maintenanceCalories,
    required this.calorieTarget,
    required this.waterTargetMl,
  });

  final int age;
  final double bmi;
  final String bmiBand;
  final double bmr;
  final double maintenanceCalories;
  final double calorieTarget;
  final int waterTargetMl;
}

abstract final class BodyMetrics {
  static int ageAt(DateTime birthDate, {DateTime? asOf}) {
    final DateTime now = asOf ?? DateTime.now();

    int age = now.year - birthDate.year;

    final bool birthdayNotReached =
        now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day);

    if (birthdayNotReached) {
      age--;
    }

    return age;
  }

  static double bmi({required double weightKg, required double heightCm}) {
    final double heightM = heightCm / 100;

    return weightKg / (heightM * heightM);
  }

  static String bmiBand(double value) {
    if (value < 18.5) {
      return 'Below standard range';
    }

    if (value < 25) {
      return 'Standard range';
    }

    if (value < 30) {
      return 'Above standard range';
    }

    return 'High range';
  }

  static double bmrMifflinStJeor({
    required String sex,
    required int age,
    required double weightKg,
    required double heightCm,
  }) {
    final double base = (10 * weightKg) + (6.25 * heightCm) - (5 * age);

    if (sex == 'male') {
      return base + 5;
    }

    if (sex == 'female') {
      return base - 161;
    }

    throw ArgumentError('sex must be male or female for this equation');
  }

  static double activityFactor(String level) {
    return switch (level) {
      'sedentary' => 1.20,
      'light' => 1.375,
      'moderate' => 1.55,
      'very_active' => 1.725,
      'athlete' => 1.90,
      _ => 1.20,
    };
  }

  static double goalFactor(String goal) {
    return switch (goal) {
      'lose' => 0.85,
      'gain' => 1.10,
      _ => 1.0,
    };
  }

  static BodyMetricsSnapshot evaluate({
    required DateTime birthDate,
    required String sex,
    required double heightCm,
    required double weightKg,
    required String activityLevel,
    required String goal,
    DateTime? asOf,
  }) {
    final int age = ageAt(birthDate, asOf: asOf);

    if (age < 18) {
      throw ArgumentError('PrFitness adult energy estimates require age 18+.');
    }

    final double bmiValue = bmi(weightKg: weightKg, heightCm: heightCm);

    final double bmrValue = bmrMifflinStJeor(
      sex: sex,
      age: age,
      weightKg: weightKg,
      heightCm: heightCm,
    );

    final double maintenance = bmrValue * activityFactor(activityLevel);

    final double target = maintenance * goalFactor(goal);

    final int hydration = (weightKg * 35).round();

    return BodyMetricsSnapshot(
      age: age,
      bmi: bmiValue,
      bmiBand: bmiBand(bmiValue),
      bmr: bmrValue,
      maintenanceCalories: maintenance,
      calorieTarget: target,
      waterTargetMl: hydration,
    );
  }
}
