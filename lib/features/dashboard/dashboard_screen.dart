import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/pr_theme.dart';
import '../../core/widgets/premium_panel.dart';
import '../profile/domain/body_metrics.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.database,
    required this.profile,
    super.key,
  });

  final AppDatabase database;
  final ProfileRow profile;

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.now();

    final BodyMetricsSnapshot baseline = BodyMetrics.evaluate(
      birthDate: profile.birthDate,
      sex: profile.sex,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      activityLevel: profile.activityLevel,
      goal: profile.goal,
    );

    return StreamBuilder<List<FoodEntry>>(
      stream: database.watchFoodForDay(today),
      builder:
          (BuildContext context, AsyncSnapshot<List<FoodEntry>> foodSnapshot) {
            return StreamBuilder<List<ActivityEntry>>(
              stream: database.watchActivityForDay(today),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<ActivityEntry>> activitySnapshot,
                  ) {
                    return StreamBuilder<List<WaterEntry>>(
                      stream: database.watchWaterForDay(today),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<List<WaterEntry>> waterSnapshot,
                          ) {
                            final List<FoodEntry> foods =
                                foodSnapshot.data ?? <FoodEntry>[];

                            final List<ActivityEntry> activities =
                                activitySnapshot.data ?? <ActivityEntry>[];

                            final List<WaterEntry> waters =
                                waterSnapshot.data ?? <WaterEntry>[];

                            final double intake = foods.fold<double>(
                              0,
                              (double total, FoodEntry entry) =>
                                  total + entry.calories,
                            );

                            final double burn = activities.fold<double>(
                              0,
                              (double total, ActivityEntry entry) =>
                                  total + entry.caloriesBurned,
                            );

                            final int water = waters.fold<int>(
                              0,
                              (int total, WaterEntry entry) =>
                                  total + entry.amountMl,
                            );

                            return _DashboardBody(
                              profile: profile,
                              baseline: baseline,
                              intake: intake,
                              burn: burn,
                              water: water,
                              activityCount: activities.length,
                            );
                          },
                    );
                  },
            );
          },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.profile,
    required this.baseline,
    required this.intake,
    required this.burn,
    required this.water,
    required this.activityCount,
  });

  final ProfileRow profile;
  final BodyMetricsSnapshot baseline;
  final double intake;
  final double burn;
  final int water;
  final int activityCount;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    final double remaining = baseline.calorieTarget - intake;

    final double progress = baseline.calorieTarget <= 0
        ? 0
        : (intake / baseline.calorieTarget).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
      children: <Widget>[
        Text(
          'Command Center',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1),
        ),
        const SizedBox(height: 5),
        Text('Good to see you, ${profile.name}.'),
        const SizedBox(height: 22),
        PremiumPanel(
          borderRadius: 34,
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 750),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(begin: 0, end: progress),
                      builder:
                          (BuildContext context, double value, Widget? child) {
                            return SizedBox(
                              width: 92,
                              height: 92,
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 8,
                                strokeCap: StrokeCap.round,
                                backgroundColor: accent.withAlpha(18),
                              ),
                            );
                          },
                    ),
                    Icon(Icons.bolt_rounded, color: accent, size: 30),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Todayâ€™s energy runway',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      remaining >= 0
                          ? '${remaining.round()} kcal estimated remaining'
                          : '${remaining.abs().round()} kcal over estimated target',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Target ${baseline.calorieTarget.round()} kcal'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.28,
          children: <Widget>[
            _MetricCard(
              icon: Icons.restaurant_rounded,
              title: 'Intake',
              value: '${intake.round()}',
              detail: 'kcal logged',
            ),
            _MetricCard(
              icon: Icons.directions_run_rounded,
              title: 'Movement',
              value: '${burn.round()}',
              detail: '$activityCount sessions',
            ),
            _MetricCard(
              icon: Icons.water_drop_rounded,
              title: 'Hydration',
              value: '$water',
              detail: 'of ${baseline.waterTargetMl} ml',
            ),
            _MetricCard(
              icon: Icons.school_rounded,
              title: 'Study target',
              value: '${profile.dailyStudyTargetMinutes}',
              detail: 'minutes',
            ),
          ],
        ),
        const SizedBox(height: 18),
        PremiumPanel(
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withAlpha(18),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'PrFitness Analyst is now using real local data. '
                  'No synthetic health score is being fabricated.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return PremiumPanel(
      borderRadius: 24,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withAlpha(16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
