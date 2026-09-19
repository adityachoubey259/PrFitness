import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/pr_theme.dart';
import '../../core/widgets/premium_panel.dart';
import '../productivity/data/productivity_repository.dart';
import '../productivity/domain/performance_engine.dart';
import '../profile/domain/body_metrics.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({required this.database, required this.profile, super.key});

  final AppDatabase database;
  final ProfileRow profile;

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.now();

    return StreamBuilder<List<Goal>>(
      stream: database.watchGoals(),
      builder: (BuildContext context, AsyncSnapshot<List<Goal>> goalsSnapshot) {
        final List<Goal> goals = goalsSnapshot.data ?? <Goal>[];

        return StreamBuilder<List<GoalCompletion>>(
          stream: database.watchGoalCompletionsForDay(today),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<GoalCompletion>> goalCompletionSnapshot,
              ) {
                final List<GoalCompletion> goalCompletions =
                    goalCompletionSnapshot.data ?? <GoalCompletion>[];

                return StreamBuilder<List<RoutineItem>>(
                  stream: database.watchRoutines(),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<RoutineItem>> routinesSnapshot,
                      ) {
                        final List<RoutineItem> routines =
                            routinesSnapshot.data ?? <RoutineItem>[];

                        return StreamBuilder<List<RoutineCompletion>>(
                          stream: database.watchRoutineCompletionsForDay(today),
                          builder:
                              (
                                BuildContext context,
                                AsyncSnapshot<List<RoutineCompletion>>
                                routineCompletionSnapshot,
                              ) {
                                final List<RoutineCompletion>
                                routineCompletions =
                                    routineCompletionSnapshot.data ??
                                    <RoutineCompletion>[];

                                return _PerformanceLoader(
                                  database: database,
                                  profile: profile,
                                  goals: goals,
                                  goalCompletions: goalCompletions,
                                  routines: routines,
                                  routineCompletions: routineCompletions,
                                );
                              },
                        );
                      },
                );
              },
        );
      },
    );
  }
}

class _PerformanceLoader extends StatelessWidget {
  const _PerformanceLoader({
    required this.database,
    required this.profile,
    required this.goals,
    required this.goalCompletions,
    required this.routines,
    required this.routineCompletions,
  });

  final AppDatabase database;
  final ProfileRow profile;
  final List<Goal> goals;
  final List<GoalCompletion> goalCompletions;
  final List<RoutineItem> routines;
  final List<RoutineCompletion> routineCompletions;

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.now();

    return StreamBuilder<List<StudySession>>(
      stream: database.watchStudyForDay(today),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<StudySession>> studySnapshot,
          ) {
            final List<StudySession> sessions =
                studySnapshot.data ?? <StudySession>[];

            return StreamBuilder<List<WaterEntry>>(
              stream: database.watchWaterForDay(today),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<WaterEntry>> waterSnapshot,
                  ) {
                    final List<WaterEntry> water =
                        waterSnapshot.data ?? <WaterEntry>[];

                    final int studyMinutes =
                        (sessions.fold<int>(
                                  0,
                                  (int sum, StudySession item) =>
                                      sum + item.durationSeconds,
                                ) /
                                60)
                            .floor();

                    final int waterMl = water.fold<int>(
                      0,
                      (int sum, WaterEntry item) => sum + item.amountMl,
                    );

                    final Set<String> completedGoalIds = goalCompletions
                        .map((GoalCompletion item) => item.goalId)
                        .toSet();

                    final Set<String> completedRoutineIds = routineCompletions
                        .map((RoutineCompletion item) => item.routineId)
                        .toSet();

                    final BodyMetricsSnapshot baseline = BodyMetrics.evaluate(
                      birthDate: profile.birthDate,
                      sex: profile.sex,
                      heightCm: profile.heightCm,
                      weightKg: profile.weightKg,
                      activityLevel: profile.activityLevel,
                      goal: profile.goal,
                    );

                    final PerformanceSnapshot performance =
                        PerformanceEngine.evaluate(
                          studyMinutes: studyMinutes,
                          studyTargetMinutes: profile.dailyStudyTargetMinutes,
                          waterMl: waterMl,
                          waterTargetMl: baseline.waterTargetMl,
                          totalGoals: goals.length,
                          completedGoals: completedGoalIds.length,
                          totalRoutines: routines.length,
                          completedRoutines: completedRoutineIds.length,
                        );

                    return _GoalsBody(
                      database: database,
                      profile: profile,
                      goals: goals,
                      completedGoalIds: completedGoalIds,
                      routines: routines,
                      completedRoutineIds: completedRoutineIds,
                      performance: performance,
                    );
                  },
            );
          },
    );
  }
}

class _GoalsBody extends StatelessWidget {
  const _GoalsBody({
    required this.database,
    required this.profile,
    required this.goals,
    required this.completedGoalIds,
    required this.routines,
    required this.completedRoutineIds,
    required this.performance,
  });

  final AppDatabase database;
  final ProfileRow profile;
  final List<Goal> goals;
  final Set<String> completedGoalIds;
  final List<RoutineItem> routines;
  final Set<String> completedRoutineIds;
  final PerformanceSnapshot performance;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    final ProductivityRepository repository = ProductivityRepository(database);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
      children: <Widget>[
        Text(
          'Execution Center',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1),
        ),
        const SizedBox(height: 5),
        const Text('Discipline measured against your own targets.'),
        const SizedBox(height: 22),

        PremiumPanel(
          borderRadius: 36,
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 122,
                height: 122,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(
                        begin: 0,
                        end: performance.score / 100,
                      ),
                      builder:
                          (BuildContext context, double value, Widget? child) {
                            return SizedBox(
                              width: 114,
                              height: 114,
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 9,
                                strokeCap: StrokeCap.round,
                                backgroundColor: accent.withAlpha(16),
                              ),
                            );
                          },
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '${performance.score}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'SCORE',
                          style: TextStyle(
                            color: accent,
                            fontSize: 9,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Daily Performance',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Attention: ${performance.focusArea}',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'This is an adherence score, not a medical or health diagnosis.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        _ScoreBreakdown(performance: performance),

        const SizedBox(height: 25),

        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Daily goals',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            IconButton.filledTonal(
              onPressed: () => _addGoal(context),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),

        const SizedBox(height: 10),

        PremiumPanel(
          child: goals.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('Create your first measurable goal.'),
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (final Goal goal in goals)
                      _CompletionRow(
                        title: goal.title,
                        subtitle: goal.category,
                        completed: completedGoalIds.contains(goal.id),
                        onChanged: (bool value) {
                          HapticFeedback.selectionClick();

                          repository.setGoalCompletedToday(
                            goalId: goal.id,
                            completed: value,
                          );
                        },
                      ),
                  ],
                ),
        ),

        const SizedBox(height: 25),

        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Routine stack',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            IconButton.filledTonal(
              onPressed: () => _addRoutine(context),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),

        const SizedBox(height: 10),

        PremiumPanel(
          child: routines.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Add skincare, workout, morning or custom routines.',
                    ),
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (final RoutineItem routine in routines)
                      _CompletionRow(
                        title: routine.title,
                        subtitle: routine.routineType,
                        completed: completedRoutineIds.contains(routine.id),
                        onChanged: (bool value) {
                          HapticFeedback.selectionClick();

                          repository.setRoutineCompletedToday(
                            routineId: routine.id,
                            completed: value,
                          );
                        },
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _addGoal(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return _CreateItemSheet(
          title: 'Create goal',
          fieldLabel: 'Goal',
          types: const <String>[
            'Personal',
            'Health',
            'Study',
            'Fitness',
            'Work',
          ],
          onSave: (String title, String type) =>
              ProductivityRepository(database)
                  .addGoal(title: title, category: type),
        );
      },
    );
  }

  Future<void> _addRoutine(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return _CreateItemSheet(
          title: 'Add routine',
          fieldLabel: 'Routine item',
          types: const <String>[
            'Morning',
            'Workout',
            'Skincare',
            'Night',
            'Personal',
          ],
          onSave: (String title, String type) =>
              ProductivityRepository(database)
                  .addRoutine(title: title, type: type),
        );
      },
    );
  }
}

class _ScoreBreakdown extends StatelessWidget {
  const _ScoreBreakdown({required this.performance});

  final PerformanceSnapshot performance;

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      child: Column(
        children: <Widget>[
          _ScoreRow(label: 'Study', ratio: performance.studyRatio),
          _ScoreRow(label: 'Hydration', ratio: performance.hydrationRatio),
          if (performance.goalRatio != null)
            _ScoreRow(label: 'Goals', ratio: performance.goalRatio!),
          if (performance.routineRatio != null)
            _ScoreRow(
              label: 'Routine',
              ratio: performance.routineRatio!,
              last: true,
            ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.ratio,
    this.last = false,
  });

  final String label;
  final double ratio;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 90,
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 7,
                    backgroundColor: accent.withAlpha(15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 42,
                child: Text(
                  '${(ratio * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
        if (!last) Divider(height: 1, color: accent.withAlpha(15)),
      ],
    );
  }
}

class _CompletionRow extends StatelessWidget {
  const _CompletionRow({
    required this.title,
    required this.subtitle,
    required this.completed,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool completed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: completed ? accent.withAlpha(12) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () => onChanged(!completed),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: completed ? accent : accent.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accent.withAlpha(completed ? 255 : 45),
                ),
              ),
              child: Icon(
                completed ? Icons.check_rounded : Icons.circle_outlined,
                color: completed
                    ? PrTheme.isBlackGold(context)
                          ? Colors.black
                          : Colors.white
                    : accent,
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateItemSheet extends StatefulWidget {
  const _CreateItemSheet({
    required this.title,
    required this.fieldLabel,
    required this.types,
    required this.onSave,
  });

  final String title;
  final String fieldLabel;
  final List<String> types;

  final Future<void> Function(String title, String type) onSave;

  @override
  State<_CreateItemSheet> createState() => _CreateItemSheetState();
}

class _CreateItemSheetState extends State<_CreateItemSheet> {
  final TextEditingController _title = TextEditingController();

  late String _type = widget.types.first;

  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.onSave(_title.text, _type);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: InputDecoration(labelText: widget.fieldLabel),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Category'),
            items: widget.types
                .map(
                  (String type) =>
                      DropdownMenuItem<String>(value: type, child: Text(type)),
                )
                .toList(),
            onChanged: (String? value) {
              if (value == null) return;

              setState(() {
                _type = value;
              });
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Create'),
            ),
          ),
        ],
      ),
    );
  }
}
