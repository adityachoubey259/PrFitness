import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/pr_theme.dart';
import '../../../core/widgets/premium_panel.dart';
import '../data/history_repository.dart';

enum _VaultFilter { all, nutrition, movement, hydration, study, weight }

class HistoryVaultScreen extends StatefulWidget {
  const HistoryVaultScreen({
    required this.database,
    required this.profile,
    required this.onProfileUpdated,
    super.key,
  });

  final AppDatabase database;
  final ProfileRow profile;

  final ValueChanged<ProfileRow> onProfileUpdated;

  @override
  State<HistoryVaultScreen> createState() => _HistoryVaultScreenState();
}

class _HistoryVaultScreenState extends State<HistoryVaultScreen> {
  late ProfileRow _profile;

  late Future<HistorySnapshot> _future;

  _VaultFilter _filter = _VaultFilter.all;

  @override
  void initState() {
    super.initState();

    _profile = widget.profile;
    _reload();
  }

  void _reload() {
    _future = HistoryRepository(widget.database).load();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('History Vault'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logWeight,
        icon: const Icon(Icons.monitor_weight_rounded),
        label: const Text('Log weight'),
      ),
      body: FutureBuilder<HistorySnapshot>(
        future: _future,
        builder:
            (BuildContext context, AsyncSnapshot<HistorySnapshot> snapshot) {
              if (snapshot.connectionState != ConnectionState.done &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'History could not be loaded.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final HistorySnapshot data = snapshot.data!;

              final List<_HistoryEvent> visible = _events(data)
                  .where(_matchesFilter)
                  .toList();

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                  children: <Widget>[
                    _BodyProgressHero(profile: _profile, weights: data.weights),

                    const SizedBox(height: 20),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _VaultFilter.values
                            .map(
                              (_VaultFilter value) => Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: ChoiceChip(
                                  label: Text(_label(value)),
                                  selected: _filter == value,
                                  onSelected: (_) {
                                    HapticFeedback.selectionClick();

                                    setState(() {
                                      _filter = value;
                                    });
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '90-day history',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          '${visible.length} records',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    if (visible.isEmpty)
                      PremiumPanel(
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: Text('No records in this category.'),
                          ),
                        ),
                      )
                    else
                      PremiumPanel(
                        child: Column(
                          children: <Widget>[
                            for (int index = 0; index < visible.length; index++)
                              _HistoryRow(
                                event: visible[index],
                                last: index == visible.length - 1,
                                onDelete: () => _delete(visible[index]),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
      ),
    );
  }

  List<_HistoryEvent> _events(HistorySnapshot data) {
    final List<_HistoryEvent> result = <_HistoryEvent>[];

    for (final FoodEntry item in data.foods) {
      result.add(
        _HistoryEvent(
          id: item.id,
          type: HistoryType.food,
          title: item.name,
          subtitle: '${item.calories.round()} kcal',
          occurredAt: item.occurredAt,
          icon: Icons.restaurant_rounded,
        ),
      );
    }

    for (final ActivityEntry item in data.activities) {
      result.add(
        _HistoryEvent(
          id: item.id,
          type: HistoryType.activity,
          title: item.activityType,
          subtitle:
              '${item.durationMinutes} min • '
              '${item.caloriesBurned.round()} kcal',
          occurredAt: item.occurredAt,
          icon: Icons.directions_run_rounded,
        ),
      );
    }

    for (final WaterEntry item in data.waters) {
      result.add(
        _HistoryEvent(
          id: item.id,
          type: HistoryType.water,
          title: 'Hydration',
          subtitle: '${item.amountMl} ml',
          occurredAt: item.occurredAt,
          icon: Icons.water_drop_rounded,
        ),
      );
    }

    for (final StudySession item in data.study) {
      result.add(
        _HistoryEvent(
          id: item.id,
          type: HistoryType.study,
          title: item.subject,
          subtitle: '${(item.durationSeconds / 60).round()} min focus',
          occurredAt: item.startedAt,
          icon: Icons.school_rounded,
        ),
      );
    }

    for (final WeightEntry item in data.weights) {
      result.add(
        _HistoryEvent(
          id: item.id,
          type: HistoryType.weight,
          title: '${item.weightKg.toStringAsFixed(1)} kg',
          subtitle: item.note ?? 'Body weight',
          occurredAt: item.occurredAt,
          icon: Icons.monitor_weight_rounded,
        ),
      );
    }

    result.sort(
      (_HistoryEvent a, _HistoryEvent b) =>
          b.occurredAt.compareTo(a.occurredAt),
    );

    return result;
  }

  bool _matchesFilter(_HistoryEvent event) {
    return switch (_filter) {
      _VaultFilter.all => true,
      _VaultFilter.nutrition => event.type == HistoryType.food,
      _VaultFilter.movement => event.type == HistoryType.activity,
      _VaultFilter.hydration => event.type == HistoryType.water,
      _VaultFilter.study => event.type == HistoryType.study,
      _VaultFilter.weight => event.type == HistoryType.weight,
    };
  }

  String _label(_VaultFilter filter) {
    return switch (filter) {
      _VaultFilter.all => 'All',
      _VaultFilter.nutrition => 'Nutrition',
      _VaultFilter.movement => 'Movement',
      _VaultFilter.hydration => 'Water',
      _VaultFilter.study => 'Study',
      _VaultFilter.weight => 'Weight',
    };
  }

  Future<void> _delete(_HistoryEvent event) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete record?'),
          content: Text('Remove "${event.title}" from your history?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await HistoryRepository(widget.database)
        .delete(type: event.type, id: event.id, profile: _profile);

    if (event.type == HistoryType.weight) {
      final ProfileRow? updated = await widget.database.getProfile();

      if (updated != null) {
        _profile = updated;

        widget.onProfileUpdated(updated);
      }
    }

    HapticFeedback.mediumImpact();

    if (mounted) {
      setState(_reload);
    }
  }

  Future<void> _logWeight() async {
    final _WeightInput? input = await showModalBottomSheet<_WeightInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return _WeightSheet(initialWeight: _profile.weightKg);
      },
    );

    if (input == null) {
      return;
    }

    final ProfileRow updated = await HistoryRepository(widget.database)
        .recordWeight(
          profile: _profile,
          weightKg: input.weightKg,
          note: input.note,
        );

    _profile = updated;

    widget.onProfileUpdated(updated);

    HapticFeedback.heavyImpact();

    if (mounted) {
      setState(_reload);
    }
  }
}

class _HistoryEvent {
  const _HistoryEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.occurredAt,
    required this.icon,
  });

  final String id;
  final HistoryType type;
  final String title;
  final String subtitle;
  final DateTime occurredAt;
  final IconData icon;
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.event,
    required this.last,
    required this.onDelete,
  });

  final _HistoryEvent event;
  final bool last;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    final DateTime time = event.occurredAt;

    final String timestamp =
        '${time.day.toString().padLeft(2, '0')}/'
        '${time.month.toString().padLeft(2, '0')} • '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withAlpha(16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(event.icon, color: accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${event.subtitle} • $timestamp',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
        if (!last) Divider(height: 1, color: accent.withAlpha(14)),
      ],
    );
  }
}

class _BodyProgressHero extends StatelessWidget {
  const _BodyProgressHero({required this.profile, required this.weights});

  final ProfileRow profile;
  final List<WeightEntry> weights;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    final List<WeightEntry> ordered = List<WeightEntry>.from(weights)
      ..sort(
        (WeightEntry a, WeightEntry b) => a.occurredAt.compareTo(b.occurredAt),
      );

    final double current = profile.weightKg;

    final double? first = ordered.isEmpty ? null : ordered.first.weightKg;

    final double change = first == null ? 0 : current - first;

    return PremiumPanel(
      borderRadius: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: accent.withAlpha(18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.monitor_weight_rounded, color: accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Body Progress',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${current.toStringAsFixed(1)} kg current'
                      '${profile.targetWeightKg == null ? '' : ' • ${profile.targetWeightKg!.toStringAsFixed(1)} kg target'}',
                    ),
                  ],
                ),
              ),
              if (first != null)
                Text(
                  '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w900),
                ),
            ],
          ),
          if (ordered.length >= 2) ...<Widget>[
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
              child: CustomPaint(
                painter: _WeightChartPainter(
                  entries: ordered,
                  accent: accent,
                  secondary: PrTheme.secondaryAccent(context),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 16),
            const Text(
              'Log at least two measurements to unlock the body trend line.',
            ),
          ],
        ],
      ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  _WeightChartPainter({
    required this.entries,
    required this.accent,
    required this.secondary,
  });

  final List<WeightEntry> entries;
  final Color accent;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) {
      return;
    }

    double minimum = entries.first.weightKg;

    double maximum = entries.first.weightKg;

    for (final WeightEntry item in entries) {
      if (item.weightKg < minimum) {
        minimum = item.weightKg;
      }

      if (item.weightKg > maximum) {
        maximum = item.weightKg;
      }
    }

    if ((maximum - minimum).abs() < 0.1) {
      maximum += 0.5;
      minimum -= 0.5;
    }

    final Path path = Path();

    for (int index = 0; index < entries.length; index++) {
      final double x = index * size.width / (entries.length - 1);

      final double normalized =
          (entries[index].weightKg - minimum) / (maximum - minimum);

      final double y = size.height - normalized * size.height;

      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withAlpha(30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(colors: <Color>[accent, secondary])
            .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.accent != accent ||
        oldDelegate.secondary != secondary;
  }
}

class _WeightInput {
  const _WeightInput({required this.weightKg, this.note});

  final double weightKg;
  final String? note;
}

class _WeightSheet extends StatefulWidget {
  const _WeightSheet({required this.initialWeight});

  final double initialWeight;

  @override
  State<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<_WeightSheet> {
  late final TextEditingController _weight;

  final TextEditingController _note = TextEditingController();

  @override
  void initState() {
    super.initState();

    _weight = TextEditingController(
      text: widget.initialWeight.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final double? value = double.tryParse(_weight.text.trim());

    if (value == null || value < 25 || value > 400) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid weight between 25 and 400 kg.'),
        ),
      );

      return;
    }

    Navigator.of(context).pop(
      _WeightInput(
        weightKg: value,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Log body weight',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _weight,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Weight',
                suffixText: 'kg',
                prefixIcon: Icon(Icons.monitor_weight_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save measurement'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
