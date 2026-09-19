import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/pr_theme.dart';
import '../../../core/widgets/premium_panel.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics_engine.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
    required this.database,
    required this.profile,
    super.key,
  });

  final AppDatabase database;
  final ProfileRow profile;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<AnalyticsSnapshot> _future;

  int _window = 30;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = AnalyticsRepository(widget.database)
        .load(profile: widget.profile, days: 30);
  }

  Future<void> _refresh() async {
    setState(_reload);

    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Analytics Cockpit'),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();

              setState(_reload);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<AnalyticsSnapshot>(
        future: _future,
        builder:
            (BuildContext context, AsyncSnapshot<AnalyticsSnapshot> snapshot) {
              if (snapshot.connectionState != ConnectionState.done &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Text(
                      'Analytics could not be loaded.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final AnalyticsSnapshot data = snapshot.data!;

              final List<DailySignal> visible =
                  _window == 7 && data.days.length > 7
                  ? data.days.sublist(data.days.length - 7)
                  : data.days;

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                  children: <Widget>[
                    _AnalystHero(data: data),

                    const SizedBox(height: 22),

                    SegmentedButton<int>(
                      segments: const <ButtonSegment<int>>[
                        ButtonSegment<int>(value: 7, label: Text('7 days')),
                        ButtonSegment<int>(value: 30, label: Text('30 days')),
                      ],
                      selected: <int>{_window},
                      onSelectionChanged: (Set<int> value) {
                        setState(() {
                          _window = value.first;
                        });
                      },
                    ),

                    const SizedBox(height: 18),

                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 11,
                      crossAxisSpacing: 11,
                      childAspectRatio: 1.3,
                      children: <Widget>[
                        _Metric(
                          icon: Icons.psychology_alt_rounded,
                          value: '${data.studyMinutes7}',
                          title: 'Study / 7d',
                          detail: 'minutes',
                        ),
                        _Metric(
                          icon: Icons.local_fire_department_rounded,
                          value: '${data.studyStreak}',
                          title: 'Study streak',
                          detail: 'target days',
                        ),
                        _Metric(
                          icon: Icons.water_drop_rounded,
                          value: '${data.hydrationStreak}',
                          title: 'Hydration streak',
                          detail: 'target days',
                        ),
                        _Metric(
                          icon: Icons.bolt_rounded,
                          value: '${data.averageConsistency7.round()}%',
                          title: 'Consistency',
                          detail: '7-day average',
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Consistency trajectory',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),

                    const SizedBox(height: 10),

                    PremiumPanel(
                      borderRadius: 30,
                      child: SizedBox(
                        height: 190,
                        child: _SignalChart(
                          values: visible
                              .map(
                                (DailySignal value) => value.score.toDouble(),
                              )
                              .toList(),
                          accent: PrTheme.accent(context),
                          secondary: PrTheme.secondaryAccent(context),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      '30-day signal map',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),

                    const SizedBox(height: 10),

                    PremiumPanel(child: _HeatMap(days: data.days)),

                    const SizedBox(height: 24),

                    Text(
                      'Personal records',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),

                    const SizedBox(height: 10),

                    PremiumPanel(
                      child: Column(
                        children: <Widget>[
                          _RecordRow(
                            icon: Icons.school_rounded,
                            label: 'Best study day',
                            value: '${data.bestStudyMinutes} min',
                          ),
                          _RecordRow(
                            icon: Icons.directions_run_rounded,
                            label: 'Movement / 30d',
                            value: '${data.activityCalories30.round()} kcal',
                          ),
                          _RecordRow(
                            icon: Icons.calendar_month_rounded,
                            label: 'Active days',
                            value: '${data.activeDays} / ${data.days.length}',
                            last: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    _StudyTrend(data: data),
                  ],
                ),
              );
            },
      ),
    );
  }
}

class _AnalystHero extends StatelessWidget {
  const _AnalystHero({required this.data});

  final AnalyticsSnapshot data;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return PremiumPanel(
      borderRadius: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[accent, PrTheme.secondaryAccent(context)],
              ),
              borderRadius: BorderRadius.circular(21),
              boxShadow: <BoxShadow>[
                BoxShadow(color: accent.withAlpha(70), blurRadius: 24),
              ],
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: PrTheme.isBlackGold(context) ? Colors.black : Colors.white,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'PrFitness Analyst',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  data.headline,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                Text(data.insight, style: const TextStyle(height: 1.42)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String value;
  final String title;
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
          Icon(icon, color: accent),
          const Spacer(),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 500),
            tween: Tween<double>(begin: 0.94, end: 1),
            builder: (BuildContext context, double scale, Widget? child) {
              return Transform.scale(
                scale: scale,
                alignment: Alignment.centerLeft,
                child: child,
              );
            },
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _HeatMap extends StatelessWidget {
  const _HeatMap({required this.days});

  final List<DailySignal> days;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: days.map((DailySignal day) {
        final double ratio = day.score / 100;

        return Tooltip(
          message: '${day.date.day}/${day.date.month} â€¢ ${day.score}%',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: Color.lerp(
                Theme.of(context).colorScheme.surface,
                accent,
                0.10 + (ratio * 0.82),
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: accent.withAlpha(20 + (ratio * 70).round()),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: <Widget>[
              Icon(icon, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                value,
                style: TextStyle(color: accent, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        if (!last) Divider(height: 1, color: accent.withAlpha(16)),
      ],
    );
  }
}

class _StudyTrend extends StatelessWidget {
  const _StudyTrend({required this.data});

  final AnalyticsSnapshot data;

  @override
  Widget build(BuildContext context) {
    final double? trend = data.studyTrendPercent;

    String value;

    if (trend == null) {
      value = 'New 7-day study momentum';
    } else if (trend >= 0) {
      value = '+${trend.round()}% vs previous 7 days';
    } else {
      value = '${trend.round()}% vs previous 7 days';
    }

    return PremiumPanel(
      child: Row(
        children: <Widget>[
          Icon(
            trend != null && trend < 0
                ? Icons.trending_down_rounded
                : Icons.trending_up_rounded,
            color: PrTheme.accent(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalChart extends StatelessWidget {
  const _SignalChart({
    required this.values,
    required this.accent,
    required this.secondary,
  });

  final List<double> values;
  final Color accent;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SignalPainter(
        values: values,
        accent: accent,
        secondary: secondary,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SignalPainter extends CustomPainter {
  _SignalPainter({
    required this.values,
    required this.accent,
    required this.secondary,
  });

  final List<double> values;
  final Color accent;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }

    final Paint grid = Paint()
      ..color = accent.withAlpha(16)
      ..strokeWidth = 1;

    for (int row = 1; row < 4; row++) {
      final double y = size.height * row / 4;

      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final Path path = Path();

    for (int index = 0; index < values.length; index++) {
      final double x = values.length == 1
          ? size.width / 2
          : index * size.width / (values.length - 1);

      final double clamped = values[index].clamp(0, 100);

      final double y = size.height - (clamped / 100 * size.height);

      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final Paint glow = Paint()
      ..color = accent.withAlpha(35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glow);

    final Paint line = Paint()
      ..shader = LinearGradient(colors: <Color>[accent, secondary])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, line);

    final Paint dot = Paint()..color = accent;

    for (int index = 0; index < values.length; index++) {
      final double x = values.length == 1
          ? size.width / 2
          : index * size.width / (values.length - 1);

      final double y =
          size.height - (values[index].clamp(0, 100) / 100 * size.height);

      canvas.drawCircle(Offset(x, y), 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _SignalPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.accent != accent ||
        oldDelegate.secondary != secondary;
  }
}
