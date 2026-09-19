class PerformanceSnapshot {
  const PerformanceSnapshot({
    required this.score,
    required this.studyRatio,
    required this.hydrationRatio,
    required this.goalRatio,
    required this.routineRatio,
    required this.focusArea,
  });

  final int score;

  final double studyRatio;
  final double hydrationRatio;
  final double? goalRatio;
  final double? routineRatio;

  final String focusArea;
}

abstract final class PerformanceEngine {
  static PerformanceSnapshot evaluate({
    required int studyMinutes,
    required int studyTargetMinutes,
    required int waterMl,
    required int waterTargetMl,
    required int totalGoals,
    required int completedGoals,
    required int totalRoutines,
    required int completedRoutines,
  }) {
    final double study = studyTargetMinutes <= 0
        ? 0
        : (studyMinutes / studyTargetMinutes).clamp(0.0, 1.0);

    final double hydration = waterTargetMl <= 0
        ? 0
        : (waterMl / waterTargetMl).clamp(0.0, 1.0);

    final double? goals = totalGoals <= 0
        ? null
        : (completedGoals / totalGoals).clamp(0.0, 1.0);

    final double? routines = totalRoutines <= 0
        ? null
        : (completedRoutines / totalRoutines).clamp(0.0, 1.0);

    double weightedTotal = 0;
    double activeWeight = 0;

    void add(double ratio, double weight) {
      weightedTotal += ratio * weight;
      activeWeight += weight;
    }

    add(study, 35);
    add(hydration, 25);

    if (goals != null) {
      add(goals, 20);
    }

    if (routines != null) {
      add(routines, 20);
    }

    final int score = activeWeight == 0
        ? 0
        : ((weightedTotal / activeWeight) * 100).round().clamp(0, 100);

    final Map<String, double> areas = <String, double>{
      'Study target': study,
      'Hydration': hydration,
    };

    if (goals != null) {
      areas['Goals'] = goals;
    }

    if (routines != null) {
      areas['Routine'] = routines;
    }

    final MapEntry<String, double> weakest = areas.entries.reduce(
      (MapEntry<String, double> a, MapEntry<String, double> b) =>
          a.value <= b.value ? a : b,
    );

    return PerformanceSnapshot(
      score: score,
      studyRatio: study,
      hydrationRatio: hydration,
      goalRatio: goals,
      routineRatio: routines,
      focusArea: weakest.key,
    );
  }
}
