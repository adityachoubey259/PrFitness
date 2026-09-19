import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/pr_theme.dart';
import '../../../core/utils/id_factory.dart';
import '../../../core/widgets/premium_panel.dart';
import '../data/history_repository.dart';
import 'data_management_screen.dart';

class HistoryVaultPlusScreen extends StatefulWidget {
  const HistoryVaultPlusScreen({
    required this.database,
    required this.profile,
    required this.onProfileUpdated,
    super.key,
  });

  final AppDatabase database;
  final ProfileRow profile;
  final ValueChanged<ProfileRow> onProfileUpdated;

  @override
  State<HistoryVaultPlusScreen> createState() => _HistoryVaultPlusScreenState();
}

class _HistoryVaultPlusScreenState extends State<HistoryVaultPlusScreen> {
  String _query = '';
  String _filter = 'all';
  late Future<HistorySnapshot> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = HistoryRepository(widget.database).load(days: 90);

  @override
  Widget build(BuildContext context) {
    final accent = PrTheme.accent(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('History Vault+'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit & Undo Center',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      DataManagementScreen(database: widget.database),
                ),
              );
              if (mounted) setState(_reload);
            },
            icon: const Icon(Icons.edit_note_rounded),
          ),
        ],
      ),
      body: FutureBuilder<HistorySnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text('History failed: ${snapshot.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final events = _events(snapshot.data!)
              .where((e) => _filter == 'all' || e.type == _filter)
              .where(
                (e) =>
                    _query.isEmpty ||
                    '${e.title} ${e.subtitle}'.toLowerCase().contains(_query),
              )
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              children: <Widget>[
                PremiumPanel(
                  borderRadius: 34,
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: accent.withAlpha(18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(Icons.history_rounded, color: accent),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '90-day searchable timeline',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Search, inspect, repeat common entries, or open precision edit/undo controls.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    labelText: 'Search history',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        <String>[
                              'all',
                              'food',
                              'activity',
                              'water',
                              'study',
                              'weight',
                            ]
                            .map(
                              (value) => Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: ChoiceChip(
                                  selected: _filter == value,
                                  label: Text(
                                    value == 'all'
                                        ? 'All'
                                        : '${value[0].toUpperCase()}${value.substring(1)}',
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _filter = value),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Records',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      '${events.length}',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (events.isEmpty)
                  const PremiumPanel(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No matching history records.'),
                    ),
                  )
                else
                  PremiumPanel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < events.length; i++)
                          Column(
                            children: <Widget>[
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 3,
                                ),
                                leading: Icon(events[i].icon, color: accent),
                                title: Text(
                                  events[i].title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Text(events[i].subtitle),
                                onTap: () => _details(events[i]),
                                trailing: events[i].repeat == null
                                    ? const Icon(Icons.chevron_right_rounded)
                                    : IconButton(
                                        tooltip: 'Repeat now',
                                        onPressed: () async {
                                          await events[i].repeat!.call();

                                          if (!context.mounted) {
                                            return;
                                          }

                                          HapticFeedback.mediumImpact();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '${events[i].title} repeated.',
                                              ),
                                            ),
                                          );
                                          setState(_reload);
                                        },
                                        icon: const Icon(Icons.replay_rounded),
                                      ),
                              ),
                              if (i != events.length - 1)
                                const Divider(height: 1),
                            ],
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

  List<_Event> _events(HistorySnapshot data) {
    final items = <_Event>[];
    for (final row in data.foods) {
      items.add(
        _Event(
          type: 'food',
          title: row.name,
          subtitle:
              '${row.calories.toStringAsFixed(0)} kcal â€¢ ${row.mealType} â€¢ ${_stamp(row.occurredAt)}',
          details:
              'Protein ${row.proteinG?.toStringAsFixed(1) ?? 'â€”'} g\nCarbs ${row.carbsG?.toStringAsFixed(1) ?? 'â€”'} g\nFat ${row.fatG?.toStringAsFixed(1) ?? 'â€”'} g\nServing ${row.servingQuantity.toStringAsFixed(1)} ${row.servingUnit}',
          icon: Icons.restaurant_rounded,
          occurredAt: row.occurredAt,
          repeat: () => widget.database.addFood(
            FoodEntriesCompanion(
              id: Value(IdFactory.uuidV4()),
              name: Value(row.name),
              calories: Value(row.calories),
              proteinG: Value(row.proteinG),
              carbsG: Value(row.carbsG),
              fatG: Value(row.fatG),
              mealType: Value(row.mealType),
              servingQuantity: Value(row.servingQuantity),
              servingUnit: Value(row.servingUnit),
              servingGrams: Value(row.servingGrams),
              occurredAt: Value(DateTime.now()),
            ),
          ),
        ),
      );
    }
    for (final row in data.activities) {
      items.add(
        _Event(
          type: 'activity',
          title: row.activityType,
          subtitle:
              '${row.durationMinutes} min â€¢ ${row.caloriesBurned.toStringAsFixed(0)} kcal â€¢ ${_stamp(row.occurredAt)}',
          details:
              'Intensity ${row.intensity}\nDistance ${row.distanceKm?.toStringAsFixed(2) ?? 'â€”'} km\nLogged burn is informational and is not added back to the food budget.',
          icon: Icons.directions_run_rounded,
          occurredAt: row.occurredAt,
          repeat: () => widget.database.addActivity(
            ActivityEntriesCompanion(
              id: Value(IdFactory.uuidV4()),
              activityType: Value(row.activityType),
              intensity: Value(row.intensity),
              durationMinutes: Value(row.durationMinutes),
              distanceKm: Value(row.distanceKm),
              caloriesBurned: Value(row.caloriesBurned),
              occurredAt: Value(DateTime.now()),
            ),
          ),
        ),
      );
    }
    for (final row in data.waters) {
      items.add(
        _Event(
          type: 'water',
          title: '${row.amountMl} ml water',
          subtitle: _stamp(row.occurredAt),
          details: 'Hydration ${row.amountMl} ml',
          icon: Icons.water_drop_rounded,
          occurredAt: row.occurredAt,
          repeat: () => widget.database.addWater(
            WaterEntriesCompanion(
              id: Value(IdFactory.uuidV4()),
              amountMl: Value(row.amountMl),
              occurredAt: Value(DateTime.now()),
            ),
          ),
        ),
      );
    }
    for (final row in data.study) {
      items.add(
        _Event(
          type: 'study',
          title: row.subject,
          subtitle:
              '${(row.durationSeconds / 60).round()} min â€¢ ${_stamp(row.startedAt)}',
          details: row.notes?.isNotEmpty == true ? row.notes! : 'No note',
          icon: Icons.school_rounded,
          occurredAt: row.startedAt,
          repeat: null,
        ),
      );
    }
    for (final row in data.weights) {
      items.add(
        _Event(
          type: 'weight',
          title: '${row.weightKg.toStringAsFixed(1)} kg',
          subtitle:
              '${row.note ?? 'Body weight'} â€¢ ${_stamp(row.occurredAt)}',
          details: 'Measurement ${row.weightKg.toStringAsFixed(1)} kg',
          icon: Icons.monitor_weight_rounded,
          occurredAt: row.occurredAt,
          repeat: null,
        ),
      );
    }
    items.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return items;
  }

  String _stamp(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _details(_Event event) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              event.title,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(event.subtitle),
            const SizedBox(height: 14),
            Text(event.details),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Open Edit & Undo Center'),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(this.context)
                      .push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DataManagementScreen(database: widget.database),
                        ),
                      )
                      .then((_) {
                        if (mounted) setState(_reload);
                      });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Event {
  const _Event({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.icon,
    required this.occurredAt,
    required this.repeat,
  });
  final String type;
  final String title;
  final String subtitle;
  final String details;
  final IconData icon;
  final DateTime occurredAt;
  final Future<void> Function()? repeat;
}
