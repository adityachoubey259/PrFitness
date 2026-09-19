class ActivityEstimate {
  const ActivityEstimate({
    required this.met,
    required this.calories,
    this.speedKmH,
  });

  final double met;
  final double calories;
  final double? speedKmH;
}

abstract final class HealthEngine {
  static ActivityEstimate estimateActivity({
    required String activityType,
    required String intensity,
    required double weightKg,
    required int durationMinutes,
    double? distanceKm,
  }) {
    if (weightKg <= 0) {
      throw ArgumentError('Weight must be positive.');
    }

    if (durationMinutes <= 0) {
      throw ArgumentError('Duration must be greater than zero.');
    }

    final double? speedKmH = distanceKm != null && distanceKm > 0
        ? distanceKm / (durationMinutes / 60)
        : null;

    final double met = _resolveMet(
      activityType: activityType,
      intensity: intensity,
      speedKmH: speedKmH,
    );

    // Standard MET energy expenditure estimate:
    // kcal/min = MET × 3.5 × body mass (kg) / 200
    final double calories = met * 3.5 * weightKg / 200 * durationMinutes;

    return ActivityEstimate(met: met, calories: calories, speedKmH: speedKmH);
  }

  static double _resolveMet({
    required String activityType,
    required String intensity,
    required double? speedKmH,
  }) {
    if (speedKmH != null) {
      if (activityType == 'Walking') {
        return _walkingMet(speedKmH);
      }

      if (activityType == 'Running') {
        return _runningMet(speedKmH);
      }

      if (activityType == 'Cycling') {
        return _cyclingMet(speedKmH);
      }
    }

    return switch (activityType) {
      'Walking' => switch (intensity) {
        'light' => 2.8,
        'vigorous' => 5.0,
        _ => 3.5,
      },
      'Running' => switch (intensity) {
        'light' => 6.5,
        'vigorous' => 12.0,
        _ => 9.3,
      },
      'Cycling' => switch (intensity) {
        'light' => 4.0,
        'vigorous' => 10.0,
        _ => 8.0,
      },
      'Strength' => switch (intensity) {
        'light' => 3.5,
        'vigorous' => 6.0,
        _ => 5.0,
      },
      'Yoga' => switch (intensity) {
        'light' => 2.3,
        'vigorous' => 4.0,
        _ => 3.0,
      },
      'Swimming' => switch (intensity) {
        'light' => 5.0,
        'vigorous' => 10.0,
        _ => 7.0,
      },
      'Sports' => switch (intensity) {
        'light' => 4.0,
        'vigorous' => 9.0,
        _ => 7.0,
      },
      _ => switch (intensity) {
        'light' => 3.0,
        'vigorous' => 7.0,
        _ => 5.0,
      },
    };
  }

  static double _walkingMet(double speedKmH) {
    if (speedKmH < 3.2) return 2.8;
    if (speedKmH < 4.8) return 3.5;
    if (speedKmH < 5.6) return 4.3;
    if (speedKmH < 6.4) return 5.0;
    return 6.0;
  }

  static double _runningMet(double speedKmH) {
    if (speedKmH < 6.8) return 6.5;
    if (speedKmH < 7.8) return 7.8;
    if (speedKmH < 8.8) return 8.5;
    if (speedKmH < 10.2) return 9.3;
    if (speedKmH < 10.8) return 10.5;
    if (speedKmH < 11.8) return 11.0;
    if (speedKmH < 12.8) return 11.8;
    if (speedKmH < 14.0) return 12.0;
    if (speedKmH < 16.0) return 14.8;
    return 16.8;
  }

  static double _cyclingMet(double speedKmH) {
    if (speedKmH < 16.0) return 4.0;
    if (speedKmH < 19.2) return 6.8;
    if (speedKmH < 22.4) return 8.0;
    if (speedKmH < 25.6) return 10.0;
    if (speedKmH < 32.0) return 12.0;
    return 16.8;
  }
}
