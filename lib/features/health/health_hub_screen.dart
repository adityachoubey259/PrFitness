import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/pr_theme.dart';
import '../../core/widgets/premium_panel.dart';
import '../profile/domain/body_metrics.dart';
import 'data/health_repository.dart';
import 'domain/health_engine.dart';

class HealthHubScreen extends StatelessWidget {
  const HealthHubScreen({
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
                            return _HealthCommandCenter(
                              database: database,
                              profile: profile,
                              baseline: baseline,
                              foods: foodSnapshot.data ?? <FoodEntry>[],
                              activities:
                                  activitySnapshot.data ?? <ActivityEntry>[],
                              waters: waterSnapshot.data ?? <WaterEntry>[],
                            );
                          },
                    );
                  },
            );
          },
    );
  }
}

class _HealthCommandCenter extends StatelessWidget {
  const _HealthCommandCenter({
    required this.database,
    required this.profile,
    required this.baseline,
    required this.foods,
    required this.activities,
    required this.waters,
  });

  final AppDatabase database;
  final ProfileRow profile;
  final BodyMetricsSnapshot baseline;
  final List<FoodEntry> foods;
  final List<ActivityEntry> activities;
  final List<WaterEntry> waters;

  double get calorieIntake => foods.fold<double>(
    0,
    (double sum, FoodEntry item) => sum + item.calories,
  );

  double get calorieBurn => activities.fold<double>(
    0,
    (double sum, ActivityEntry item) => sum + item.caloriesBurned,
  );

  double get protein => foods.fold<double>(
    0,
    (double sum, FoodEntry item) => sum + (item.proteinG ?? 0),
  );

  double get carbs => foods.fold<double>(
    0,
    (double sum, FoodEntry item) => sum + (item.carbsG ?? 0),
  );

  double get fat => foods.fold<double>(
    0,
    (double sum, FoodEntry item) => sum + (item.fatG ?? 0),
  );

  int get waterMl =>
      waters.fold<int>(0, (int sum, WaterEntry item) => sum + item.amountMl);

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    final double netIntake = calorieIntake - calorieBurn;

    final double remaining = baseline.calorieTarget - netIntake;

    final double calorieProgress = baseline.calorieTarget <= 0
        ? 0
        : (netIntake / baseline.calorieTarget).clamp(0.0, 1.0);

    final double waterProgress = baseline.waterTargetMl <= 0
        ? 0
        : (waterMl / baseline.waterTargetMl).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Health Intelligence',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live body • nutrition • movement • hydration',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            _LiveIndicator(accent: accent),
          ],
        ),
        const SizedBox(height: 24),

        PremiumPanel(
          borderRadius: 34,
          padding: const EdgeInsets.all(22),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget ring = _EnergyRing(
                progress: calorieProgress,
                remaining: remaining,
              );

              final Widget information = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Energy runway',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    remaining >= 0
                        ? '${remaining.round()} kcal estimated remaining'
                        : '${remaining.abs().round()} kcal above estimated target',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: accent, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Target ${baseline.calorieTarget.round()} kcal • '
                    'Intake ${calorieIntake.round()} • '
                    'Activity ${calorieBurn.round()}',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Energy values are estimates, not direct metabolic measurements.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );

              if (constraints.maxWidth < 520) {
                return Column(
                  children: <Widget>[
                    ring,
                    const SizedBox(height: 20),
                    Align(alignment: Alignment.centerLeft, child: information),
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  ring,
                  const SizedBox(width: 25),
                  Expanded(child: information),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: <Widget>[
            Expanded(
              child: _PremiumAction(
                icon: Icons.restaurant_rounded,
                label: 'Log food',
                onPressed: () => _showFoodSheet(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PremiumAction(
                icon: Icons.directions_run_rounded,
                label: 'Movement',
                onPressed: () => _showActivitySheet(context),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        Text(
          'Nutrition matrix',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: 12),

        PremiumPanel(
          borderRadius: 28,
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MacroMetric(label: 'Protein', value: protein),
                  ),
                  Expanded(
                    child: _MacroMetric(label: 'Carbs', value: carbs),
                  ),
                  Expanded(
                    child: _MacroMetric(label: 'Fat', value: fat),
                  ),
                ],
              ),
              if (foods.isNotEmpty) ...<Widget>[
                const SizedBox(height: 15),
                Divider(color: accent.withAlpha(20)),
                for (final FoodEntry item in foods.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withAlpha(18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        color: accent,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_foodSubtitle(item)),
                    trailing: Text(
                      '${item.calories.round()} kcal',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'Hydration',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: 12),

        PremiumPanel(
          borderRadius: 28,
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(18),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Icon(
                      Icons.water_drop_rounded,
                      color: accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '$waterMl ml',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text('Baseline ${baseline.waterTargetMl} ml'),
                      ],
                    ),
                  ),
                  Text(
                    '${(waterProgress * 100).round()}%',
                    style: TextStyle(
                      color: accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0, end: waterProgress),
                  builder: (BuildContext context, double value, Widget? child) {
                    return LinearProgressIndicator(value: value, minHeight: 9);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _addWater(250),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('250 ml'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _addWater(500),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('500 ml'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (activities.isNotEmpty) ...<Widget>[
          const SizedBox(height: 24),
          Text(
            'Movement timeline',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          PremiumPanel(
            child: Column(
              children: <Widget>[
                for (final ActivityEntry item in activities.take(6))
                  _ActivityRow(activity: item),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _foodSubtitle(FoodEntry item) {
    final List<String> values = <String>[];

    if (item.proteinG != null) {
      values.add('P ${item.proteinG!.round()}g');
    }

    if (item.carbsG != null) {
      values.add('C ${item.carbsG!.round()}g');
    }

    if (item.fatG != null) {
      values.add('F ${item.fatG!.round()}g');
    }

    return values.isEmpty ? 'Nutrition entry' : values.join(' • ');
  }

  Future<void> _addWater(int amountMl) async {
    HapticFeedback.selectionClick();

    await HealthRepository(database).addWater(amountMl);
  }

  Future<void> _showFoodSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return _FoodEntrySheet(repository: HealthRepository(database));
      },
    );
  }

  Future<void> _showActivitySheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return _ActivityEntrySheet(
          repository: HealthRepository(database),
          weightKg: profile.weightKg,
        );
      },
    );
  }
}

class _EnergyRing extends StatelessWidget {
  const _EnergyRing({required this.progress, required this.remaining});

  final double progress;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: 0, end: progress),
            builder: (BuildContext context, double value, Widget? child) {
              return SizedBox(
                width: 122,
                height: 122,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 9,
                  strokeCap: StrokeCap.round,
                  backgroundColor: accent.withAlpha(18),
                ),
              );
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${remaining.abs().round()}',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                remaining >= 0 ? 'LEFT' : 'OVER',
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withAlpha(16),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: accent.withAlpha(35)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              boxShadow: <BoxShadow>[
                BoxShadow(color: accent.withAlpha(100), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroMetric extends StatelessWidget {
  const _MacroMetric({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          '${value.round()}g',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _PremiumAction extends StatelessWidget {
  const _PremiumAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 55,
      child: FilledButton.tonalIcon(
        onPressed: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final ActivityEntry activity;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withAlpha(16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.directions_run_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  activity.activityType,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${activity.durationMinutes} min'
                  '${activity.distanceKm == null ? '' : ' • ${activity.distanceKm!.toStringAsFixed(2)} km'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${activity.caloriesBurned.round()} kcal',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _FoodEntrySheet extends StatefulWidget {
  const _FoodEntrySheet({required this.repository});

  final HealthRepository repository;

  @override
  State<_FoodEntrySheet> createState() => _FoodEntrySheetState();
}

class _FoodEntrySheetState extends State<_FoodEntrySheet> {
  final TextEditingController _name = TextEditingController();

  final TextEditingController _calories = TextEditingController();

  final TextEditingController _protein = TextEditingController();

  final TextEditingController _carbs = TextEditingController();

  final TextEditingController _fat = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();

    super.dispose();
  }

  double? _optional(TextEditingController controller) {
    final String value = controller.text.trim();

    if (value.isEmpty) {
      return null;
    }

    return double.tryParse(value);
  }

  Future<void> _save() async {
    final double? calories = double.tryParse(_calories.text.trim());

    if (_name.text.trim().isEmpty || calories == null || calories <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a food name and valid calories.')),
      );

      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.repository.addFood(
        name: _name.text,
        calories: calories,
        proteinG: _optional(_protein),
        carbsG: _optional(_carbs),
        fatG: _optional(_fat),
      );

      HapticFeedback.mediumImpact();

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
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Log nutrition',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text(
              'Add the values from the food label or your measured portion.',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Food / meal',
                prefixIcon: Icon(Icons.restaurant_menu_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _calories,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Calories',
                suffixText: 'kcal',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _protein,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Protein',
                      suffixText: 'g',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _carbs,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Carbs',
                      suffixText: 'g',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fat,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Fat',
                      suffixText: 'g',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.add_rounded),
                label: Text(_saving ? 'Saving...' : 'Add to today'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityEntrySheet extends StatefulWidget {
  const _ActivityEntrySheet({required this.repository, required this.weightKg});

  final HealthRepository repository;
  final double weightKg;

  @override
  State<_ActivityEntrySheet> createState() => _ActivityEntrySheetState();
}

class _ActivityEntrySheetState extends State<_ActivityEntrySheet> {
  String _activity = 'Walking';
  String _intensity = 'moderate';

  final TextEditingController _minutes = TextEditingController(text: '30');

  final TextEditingController _distance = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _minutes.dispose();
    _distance.dispose();

    super.dispose();
  }

  ActivityEstimate? get _preview {
    final int? minutes = int.tryParse(_minutes.text.trim());

    if (minutes == null || minutes <= 0) {
      return null;
    }

    final double? distance = double.tryParse(_distance.text.trim());

    return HealthEngine.estimateActivity(
      activityType: _activity,
      intensity: _intensity,
      weightKg: widget.weightKg,
      durationMinutes: minutes,
      distanceKm: distance,
    );
  }

  Future<void> _save() async {
    final int? minutes = int.tryParse(_minutes.text.trim());

    if (minutes == null || minutes <= 0) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.repository.addActivity(
        activityType: _activity,
        intensity: _intensity,
        weightKg: widget.weightKg,
        durationMinutes: minutes,
        distanceKm: double.tryParse(_distance.text.trim()),
      );

      HapticFeedback.mediumImpact();

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
    final ActivityEstimate? preview = _preview;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Movement intelligence',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text(
              'Distance is optional. When supplied, pace helps refine the MET estimate.',
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _activity,
              decoration: const InputDecoration(labelText: 'Activity'),
              items:
                  const <String>[
                        'Walking',
                        'Running',
                        'Cycling',
                        'Strength',
                        'Yoga',
                        'Swimming',
                        'Sports',
                      ]
                      .map(
                        (String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
              onChanged: (String? value) {
                if (value == null) return;

                setState(() {
                  _activity = value;
                });
              },
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'light', label: Text('Light')),
                ButtonSegment<String>(
                  value: 'moderate',
                  label: Text('Moderate'),
                ),
                ButtonSegment<String>(
                  value: 'vigorous',
                  label: Text('Vigorous'),
                ),
              ],
              selected: <String>{_intensity},
              onSelectionChanged: (Set<String> values) {
                setState(() {
                  _intensity = values.first;
                });
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _minutes,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Duration',
                      suffixText: 'min',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _distance,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Distance',
                      suffixText: 'km',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PremiumPanel(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: PrTheme.accent(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Estimated output',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          preview == null
                              ? 'Enter duration'
                              : '${preview.met.toStringAsFixed(1)} MET'
                                    '${preview.speedKmH == null ? '' : ' • ${preview.speedKmH!.toStringAsFixed(1)} km/h'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    preview == null ? '--' : '${preview.calories.round()} kcal',
                    style: TextStyle(
                      color: PrTheme.accent(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.bolt_rounded),
                label: Text(_saving ? 'Saving...' : 'Commit activity'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
