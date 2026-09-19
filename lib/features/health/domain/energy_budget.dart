class EnergyBudget {
  const EnergyBudget({
    required this.baselineTargetKcal,
    required this.intakeKcal,
    required this.loggedActivityKcal,
  });

  /// Daily food budget already derives from the selected overall activity
  /// level. Logged exercise is displayed separately and is NOT added back
  /// into the food budget, preventing exercise double-counting.
  final double baselineTargetKcal;
  final double intakeKcal;
  final double loggedActivityKcal;

  double get remainingKcal => baselineTargetKcal - intakeKcal;

  double get intakeProgress {
    if (baselineTargetKcal <= 0) return 0;
    return (intakeKcal / baselineTargetKcal).clamp(0, 2);
  }

  double get informationalNetAfterLoggedActivity =>
      intakeKcal - loggedActivityKcal;

  String get activityDisclosure =>
      'Logged activity estimate — not added back to calorie budget.';
}
