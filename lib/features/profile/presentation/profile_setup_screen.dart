import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/pr_theme.dart';
import '../../../core/widgets/premium_backdrop.dart';
import '../../../core/widgets/premium_panel.dart';
import '../data/profile_repository.dart';
import '../domain/body_metrics.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    required this.database,
    required this.onCompleted,
    super.key,
    this.existing,
  });

  final AppDatabase database;
  final ProfileRow? existing;
  final ValueChanged<ProfileRow> onCompleted;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _name;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _targetWeight;

  DateTime? _birthDate;

  String _sex = 'male';
  String _activity = 'moderate';
  String _goal = 'maintain';

  int _studyMinutes = 120;
  int _step = 0;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final ProfileRow? profile = widget.existing;

    _name = TextEditingController(text: profile?.name ?? '');

    _height = TextEditingController(
      text: profile == null ? '' : profile.heightCm.toStringAsFixed(0),
    );

    _weight = TextEditingController(
      text: profile == null ? '' : profile.weightKg.toStringAsFixed(1),
    );

    _targetWeight = TextEditingController(
      text: profile?.targetWeightKg == null
          ? ''
          : profile!.targetWeightKg!.toStringAsFixed(1),
    );

    _birthDate = profile?.birthDate;
    _sex = profile?.sex ?? 'male';
    _activity = profile?.activityLevel ?? 'moderate';
    _goal = profile?.goal ?? 'maintain';

    _studyMinutes = profile?.dailyStudyTargetMinutes ?? 120;
  }

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _weight.dispose();
    _targetWeight.dispose();

    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final DateTime now = DateTime.now();

    final DateTime latest = DateTime(now.year - 18, now.month, now.day);

    final DateTime pickedInitial = _birthDate ?? DateTime(now.year - 25);

    final DateTime? result = await showDatePicker(
      context: context,
      initialDate: pickedInitial.isAfter(latest) ? latest : pickedInitial,
      firstDate: DateTime(now.year - 100),
      lastDate: latest,
    );

    if (result != null) {
      setState(() {
        _birthDate = result;
      });
    }
  }

  double? get _heightValue => double.tryParse(_height.text.trim());

  double? get _weightValue => double.tryParse(_weight.text.trim());

  double? get _targetWeightValue {
    final String value = _targetWeight.text.trim();

    if (value.isEmpty) {
      return null;
    }

    return double.tryParse(value);
  }

  bool _validateCurrentStep() {
    if (_step == 0) {
      if (_name.text.trim().length < 2) {
        _message('Enter your name to continue.');

        return false;
      }

      if (_birthDate == null) {
        _message('Select your date of birth.');

        return false;
      }
    }

    if (_step == 1) {
      final double? height = _heightValue;
      final double? weight = _weightValue;

      if (height == null || height < 100 || height > 250) {
        _message('Enter a valid height between 100 and 250 cm.');

        return false;
      }

      if (weight == null || weight < 25 || weight > 400) {
        _message('Enter a valid weight between 25 and 400 kg.');

        return false;
      }
    }

    return true;
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _next() {
    if (!_validateCurrentStep()) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _step++;
    });
  }

  void _back() {
    if (_step == 0) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _step--;
    });
  }

  BodyMetricsSnapshot? _snapshot() {
    final double? height = _heightValue;
    final double? weight = _weightValue;

    if (_birthDate == null || height == null || weight == null) {
      return null;
    }

    return BodyMetrics.evaluate(
      birthDate: _birthDate!,
      sex: _sex,
      heightCm: height,
      weightKg: weight,
      activityLevel: _activity,
      goal: _goal,
    );
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final double? height = _heightValue;
    final double? weight = _weightValue;

    if (_birthDate == null || height == null || weight == null) {
      _message('Complete all required profile information.');

      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final ProfileRow saved = await ProfileRepository(widget.database).save(
        existing: widget.existing,
        name: _name.text,
        birthDate: _birthDate!,
        sex: _sex,
        heightCm: height,
        weightKg: weight,
        targetWeightKg: _targetWeightValue,
        activityLevel: _activity,
        goal: _goal,
        dailyStudyTargetMinutes: _studyMinutes,
      );

      HapticFeedback.mediumImpact();

      widget.onCompleted(saved);
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
    final Color accent = PrTheme.accent(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackdrop(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: <Widget>[
                    if (_step > 0)
                      IconButton(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back_rounded),
                      )
                    else
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              accent,
                              PrTheme.secondaryAccent(context),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          color: PrTheme.isBlackGold(context)
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.existing == null
                            ? 'Build your baseline'
                            : 'Refine your baseline',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    Text(
                      '${_step + 1}/4',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / 4,
                    minHeight: 5,
                    backgroundColor: accent.withAlpha(20),
                    color: accent,
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.05, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                  child: SingleChildScrollView(
                    key: ValueKey<int>(_step),
                    padding: const EdgeInsets.all(20),
                    child: _buildStep(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _saving
                        ? null
                        : _step == 3
                        ? _save
                        : _next,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(
                            _step == 3 ? 'Activate PrFitness' : 'Continue',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _identityStep(),
      1 => _bodyStep(),
      2 => _rhythmStep(),
      _ => _intelligenceStep(),
    };
  }

  Widget _heading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _identityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _heading(
          'This starts with you.',
          'PrFitness builds a private baseline first, '
              'then turns your real daily data into intelligence.',
        ),
        PremiumPanel(
          child: Column(
            children: <Widget>[
              TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _pickBirthDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  child: Text(
                    _birthDate == null
                        ? 'Select date'
                        : '${_birthDate!.day.toString().padLeft(2, '0')}/'
                              '${_birthDate!.month.toString().padLeft(2, '0')}/'
                              '${_birthDate!.year}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bodyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _heading(
          'Your physical baseline.',
          'These values drive energy and activity estimates. '
              'They remain editable at any time.',
        ),
        PremiumPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Sex used for energy equation',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _choice(
                      'Male',
                      _sex == 'male',
                      () => setState(() => _sex = 'male'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _choice(
                      'Female',
                      _sex == 'female',
                      () => setState(() => _sex = 'female'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _height,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Height',
                        suffixText: 'cm',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Weight',
                        suffixText: 'kg',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _targetWeight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Target weight (optional)',
                  suffixText: 'kg',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rhythmStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _heading(
          'Define your operating rhythm.',
          'PrFitness adapts the baseline to how active '
              'you actually are and what you are working toward.',
        ),
        PremiumPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _SectionLabel(text: 'Activity level'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _choice(
                    'Sedentary',
                    _activity == 'sedentary',
                    () => setState(() => _activity = 'sedentary'),
                  ),
                  _choice(
                    'Light',
                    _activity == 'light',
                    () => setState(() => _activity = 'light'),
                  ),
                  _choice(
                    'Moderate',
                    _activity == 'moderate',
                    () => setState(() => _activity = 'moderate'),
                  ),
                  _choice(
                    'Very active',
                    _activity == 'very_active',
                    () => setState(() => _activity = 'very_active'),
                  ),
                  _choice(
                    'Athlete',
                    _activity == 'athlete',
                    () => setState(() => _activity = 'athlete'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionLabel(text: 'Primary body goal'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _choice(
                    'Fat loss',
                    _goal == 'lose',
                    () => setState(() => _goal = 'lose'),
                  ),
                  _choice(
                    'Maintain',
                    _goal == 'maintain',
                    () => setState(() => _goal = 'maintain'),
                  ),
                  _choice(
                    'Gain',
                    _goal == 'gain',
                    () => setState(() => _goal = 'gain'),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Row(
                children: <Widget>[
                  const Expanded(
                    child: _SectionLabel(text: 'Daily study target'),
                  ),
                  Text(
                    '${(_studyMinutes / 60).toStringAsFixed(1)} h',
                    style: TextStyle(
                      color: PrTheme.accent(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Slider(
                min: 30,
                max: 480,
                divisions: 15,
                value: _studyMinutes.toDouble(),
                onChanged: (double value) {
                  setState(() {
                    _studyMinutes = value.round();
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _intelligenceStep() {
    final BodyMetricsSnapshot? snapshot = _snapshot();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _heading(
          'Your baseline is ready.',
          'These are mathematical estimates, not medical '
              'measurements. PrFitness will refine your day '
              'using your actual logs.',
        ),
        if (snapshot != null)
          PremiumPanel(
            borderRadius: 32,
            child: Column(
              children: <Widget>[
                _metric('Age', '${snapshot.age}'),
                _metric(
                  'BMI',
                  snapshot.bmi.toStringAsFixed(1),
                  caption: snapshot.bmiBand,
                ),
                _metric('Estimated BMR', '${snapshot.bmr.round()} kcal'),
                _metric(
                  'Estimated maintenance',
                  '${snapshot.maintenanceCalories.round()} kcal',
                ),
                _metric(
                  'Goal baseline',
                  '${snapshot.calorieTarget.round()} kcal',
                ),
                _metric(
                  'Hydration baseline',
                  '${snapshot.waterTargetMl} ml',
                  last: true,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) {
    final Color accent = PrTheme.accent(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? accent.withAlpha(24) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? accent : accent.withAlpha(28)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? accent : null,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _metric(
    String label,
    String value, {
    String? caption,
    bool last = false,
  }) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label),
                    if (caption != null)
                      Text(
                        caption,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: PrTheme.accent(context),
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
        if (!last)
          Divider(height: 1, color: PrTheme.accent(context).withAlpha(20)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}
