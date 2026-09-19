import 'dart:math';

class DailySignal {
  const DailySignal({
    required this.date,
    required this.studyMinutes,
    required this.waterMl,
    required this.intakeCalories,
    required this.activityCalories,
    required this.goalCompletions,
    required this.routineCompletions,
    required this.score,
    required this.studyRatio,
    required this.hydrationRatio,
    this.goalRatio,
    this.routineRatio,
  });

  final DateTime date;

  final int studyMinutes;
  final int waterMl;

  final double intakeCalories;
  final double activityCalories;

  final int goalCompletions;
  final int routineCompletions;

  final int score;

  final double studyRatio;
  final double hydrationRatio;

  final double? goalRatio;
  final double? routineRatio;

  bool get hasActivity =>
      studyMinutes > 0 ||
      waterMl > 0 ||
      intakeCalories > 0 ||
      activityCalories > 0 ||
      goalCompletions > 0 ||
      routineCompletions > 0;
}

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.days,
    required this.studyStreak,
    required this.hydrationStreak,
    required this.studyMinutes7,
    required this.studyMinutesPrevious7,
    required this.averageConsistency7,
    required this.bestStudyMinutes,
    required this.activityCalories30,
    required this.activeDays,
    required this.headline,
    required this.insight,
  });

  final List<DailySignal> days;

  final int studyStreak;
  final int hydrationStreak;

  final int studyMinutes7;
  final int studyMinutesPrevious7;

  final double averageConsistency7;

  final int bestStudyMinutes;

  final double activityCalories30;

  final int activeDays;

  final String headline;
  final String insight;

  double? get studyTrendPercent {
    if (studyMinutesPrevious7 == 0) {
      return studyMinutes7 == 0 ? 0 : null;
    }

    return ((studyMinutes7 - studyMinutesPrevious7) / studyMinutesPrevious7) *
        100;
  }
}

abstract final class AnalyticsEngine {
  static AnalyticsSnapshot summarize(List<DailySignal> source) {
    final List<DailySignal> days = List<DailySignal>.from(source)
      ..sort((DailySignal a, DailySignal b) => a.date.compareTo(b.date));

    if (days.isEmpty) {
      return const AnalyticsSnapshot(
        days: <DailySignal>[],
        studyStreak: 0,
        hydrationStreak: 0,
        studyMinutes7: 0,
        studyMinutesPrevious7: 0,
        averageConsistency7: 0,
        bestStudyMinutes: 0,
        activityCalories30: 0,
        activeDays: 0,
        headline: 'Build your signal',
        insight:
            'Start logging real activity so PrFitness can detect patterns.',
      );
    }

    final List<DailySignal> last7 = days.length <= 7
        ? days
        : days.sublist(days.length - 7);

    final int previousEnd = max(0, days.length - 7);

    final int previousStart = max(0, previousEnd - 7);

    final List<DailySignal> previous7 = days.sublist(
      previousStart,
      previousEnd,
    );

    int sumStudy(List<DailySignal> values) => values.fold<int>(
      0,
      (int sum, DailySignal day) => sum + day.studyMinutes,
    );

    final int currentStudy = sumStudy(last7);

    final int previousStudy = sumStudy(previous7);

    final double averageScore = last7.isEmpty
        ? 0
        : last7.fold<double>(
                0,
                (double sum, DailySignal day) => sum + day.score,
              ) /
              last7.length;

    final int studyStreak = _streak(
      days,
      (DailySignal day) => day.studyRatio >= 1,
    );

    final int hydrationStreak = _streak(
      days,
      (DailySignal day) => day.hydrationRatio >= 1,
    );

    final int bestStudy = days.fold<int>(
      0,
      (int value, DailySignal day) => max(value, day.studyMinutes),
    );

    final double movement = days.fold<double>(
      0,
      (double sum, DailySignal day) => sum + day.activityCalories,
    );

    final int activeDays = days
        .where((DailySignal day) => day.hasActivity)
        .length;

    final (String, String) analyst = _analyst(last7);

    return AnalyticsSnapshot(
      days: days,
      studyStreak: studyStreak,
      hydrationStreak: hydrationStreak,
      studyMinutes7: currentStudy,
      studyMinutesPrevious7: previousStudy,
      averageConsistency7: averageScore,
      bestStudyMinutes: bestStudy,
      activityCalories30: movement,
      activeDays: activeDays,
      headline: analyst.$1,
      insight: analyst.$2,
    );
  }

  static int _streak(
    List<DailySignal> days,
    bool Function(DailySignal day) qualifies,
  ) {
    int result = 0;

    for (int index = days.length - 1; index >= 0; index--) {
      if (!qualifies(days[index])) {
        break;
      }

      result++;
    }

    return result;
  }

  static (String, String) _analyst(List<DailySignal> days) {
    if (days.isEmpty || days.every((DailySignal day) => !day.hasActivity)) {
      return (
        'Signal building',
        'There is not enough recent activity to identify a meaningful pattern yet.',
      );
    }

    double average(double Function(DailySignal value) selector) {
      return days.fold<double>(
            0,
            (double sum, DailySignal day) => sum + selector(day),
          ) /
          days.length;
    }

    final Map<String, double> areas = <String, double>{
      'Study': average((DailySignal value) => value.studyRatio),
      'Hydration': average((DailySignal value) => value.hydrationRatio),
    };

    final List<double> goalValues = days
        .where((DailySignal value) => value.goalRatio != null)
        .map((DailySignal value) => value.goalRatio!)
        .toList();

    if (goalValues.isNotEmpty) {
      areas['Goals'] =
          goalValues.reduce((double a, double b) => a + b) / goalValues.length;
    }

    final List<double> routineValues = days
        .where((DailySignal value) => value.routineRatio != null)
        .map((DailySignal value) => value.routineRatio!)
        .toList();

    if (routineValues.isNotEmpty) {
      areas['Routine'] =
          routineValues.reduce((double a, double b) => a + b) /
          routineValues.length;
    }

    final MapEntry<String, double> weakest = areas.entries.reduce(
      (MapEntry<String, double> a, MapEntry<String, double> b) =>
          a.value <= b.value ? a : b,
    );

    if (weakest.value >= 0.9) {
      return (
        'Execution is highly consistent',
        'Your recent adherence is balanced. Protect the routine rather than adding unnecessary complexity.',
      );
    }

    if (weakest.value >= 0.7) {
      return (
        '${weakest.key} has the clearest upside',
        'You are close to strong consistency. Small improvements in ${weakest.key.toLowerCase()} should have the highest leverage.',
      );
    }

    return (
      '${weakest.key} is the primary gap',
      'Recent data shows ${weakest.key.toLowerCase()} trailing your other tracked areas. Prioritize one repeatable improvement before adding more goals.',
    );
  }
}
