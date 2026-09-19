import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/pr_theme.dart';
import '../../../core/widgets/premium_panel.dart';
import '../../reminders/data/reminder_repository.dart';
import '../data/record_edit_service.dart';

enum _Kind { food, activity, water, study, weight, goals, routines, reminders }

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({required this.database, super.key});
  final AppDatabase database;

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  late final RecordEditService _editor = RecordEditService(widget.database);
  _Kind _kind = _Kind.food;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final accent = PrTheme.accent(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Edit & Undo Center'),
      ),
      body: ListView(
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
                  child: Icon(Icons.edit_note_rounded, color: accent),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Precision data control',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Edit tracked records or delete with a short undo window. Sync outbox triggers preserve cloud consistency.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _Kind.values
                  .map(
                    (kind) => Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        selected: _kind == kind,
                        label: Text(_label(kind)),
                        onSelected: (_) => setState(() => _kind = kind),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Search records',
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<_Row>>(
            future: _load(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final rows = snapshot.data!;
              if (rows.isEmpty) {
                return const PremiumPanel(child: Text('No matching records.'));
              }
              return PremiumPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < rows.length; i++)
                      Column(
                        children: <Widget>[
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 3,
                            ),
                            title: Text(
                              rows[i].title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(rows[i].subtitle),
                            onTap: () => _edit(rows[i]),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded),
                                  onPressed: () => _edit(rows[i]),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  onPressed: () => _delete(rows[i]),
                                ),
                              ],
                            ),
                          ),
                          if (i != rows.length - 1) const Divider(height: 1),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _label(_Kind k) => switch (k) {
    _Kind.food => 'Food',
    _Kind.activity => 'Activity',
    _Kind.water => 'Water',
    _Kind.study => 'Study',
    _Kind.weight => 'Weight',
    _Kind.goals => 'Goals',
    _Kind.routines => 'Routines',
    _Kind.reminders => 'Reminders',
  };

  Future<List<_Row>> _load() async {
    final rows = <_Row>[];
    bool match(String value) =>
        _query.isEmpty || value.toLowerCase().contains(_query);

    switch (_kind) {
      case _Kind.food:
        final data =
            await (widget.database.select(widget.database.foodEntries)
                  ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
                  ..limit(100))
                .get();
        for (final r in data) {
          if (match(r.name)) {
            rows.add(
              _Row(
                r,
                r.name,
                '${r.calories.toStringAsFixed(0)} kcal â€¢ ${r.mealType}',
              ),
            );
          }
        }
      case _Kind.activity:
        final data =
            await (widget.database.select(widget.database.activityEntries)
                  ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
                  ..limit(100))
                .get();
        for (final r in data) {
          if (match(r.activityType)) {
            rows.add(
              _Row(
                r,
                r.activityType,
                '${r.durationMinutes} min â€¢ ${r.caloriesBurned.toStringAsFixed(0)} kcal',
              ),
            );
          }
        }
      case _Kind.water:
        final data =
            await (widget.database.select(widget.database.waterEntries)
                  ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
                  ..limit(100))
                .get();
        for (final r in data) {
          if (match('${r.amountMl}')) {
            rows.add(_Row(r, '${r.amountMl} ml', 'Hydration'));
          }
        }
      case _Kind.study:
        final data =
            await (widget.database.select(widget.database.studySessions)
                  ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
                  ..limit(100))
                .get();
        for (final r in data) {
          if (match(r.subject)) {
            rows.add(
              _Row(r, r.subject, '${(r.durationSeconds / 60).round()} min'),
            );
          }
        }
      case _Kind.weight:
        final data =
            await (widget.database.select(widget.database.weightEntries)
                  ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
                  ..limit(100))
                .get();
        for (final r in data) {
          if (match('${r.weightKg}')) {
            rows.add(
              _Row(
                r,
                '${r.weightKg.toStringAsFixed(1)} kg',
                r.note ?? 'Body weight',
              ),
            );
          }
        }
      case _Kind.goals:
        final data = await widget.database.select(widget.database.goals).get();
        for (final r in data) {
          if (match(r.title)) {
            rows.add(_Row(r, r.title, '${r.category} â€¢ ${r.frequency}'));
          }
        }
      case _Kind.routines:
        final data = await widget.database
            .select(widget.database.routineItems)
            .get();
        for (final r in data) {
          if (match(r.title)) {
            rows.add(
              _Row(r, r.title, '${r.routineType} â€¢ order ${r.sortOrder}'),
            );
          }
        }
      case _Kind.reminders:
        final data = await widget.database
            .select(widget.database.reminders)
            .get();
        for (final r in data) {
          if (match(r.title)) {
            rows.add(
              _Row(
                r,
                r.title,
                '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')} â€¢ ${r.enabled ? 'on' : 'off'}',
              ),
            );
          }
        }
    }
    return rows;
  }

  Future<void> _edit(_Row row) async {
    final value = row.value;
    bool changed = false;

    if (value is FoodEntry) {
      changed = await _editFood(value);
    } else if (value is ActivityEntry) {
      changed = await _editActivity(value);
    } else if (value is WaterEntry) {
      changed = await _editWater(value);
    } else if (value is StudySession) {
      changed = await _editStudy(value);
    } else if (value is WeightEntry) {
      changed = await _editWeight(value);
    } else if (value is Goal) {
      changed = await _editGoal(value);
    } else if (value is RoutineItem) {
      changed = await _editRoutine(value);
    } else if (value is Reminder) {
      changed = await _editReminder(value);
    }

    if (!mounted) {
      return;
    }

    if (changed) {
      HapticFeedback.selectionClick();
      setState(() {});
    }
  }

  Future<void> _delete(_Row row) async {
    final value = row.value;
    late final UndoRecord token;

    if (value is FoodEntry) {
      token = await _editor.deleteFood(value);
    } else if (value is ActivityEntry) {
      token = await _editor.deleteActivity(value);
    } else if (value is WaterEntry) {
      token = await _editor.deleteWater(value);
    } else if (value is StudySession) {
      token = await _editor.deleteStudy(value);
    } else if (value is WeightEntry) {
      token = await _editor.deleteWeight(value);
    } else if (value is Goal) {
      token = await _editor.deleteGoal(value);
    } else if (value is RoutineItem) {
      token = await _editor.deleteRoutine(value);
    } else if (value is Reminder) {
      token = await _editor.deleteReminder(value);
    } else {
      return;
    }

    if (value is Reminder) {
      await ReminderRepository(
        widget.database,
      ).rescheduleEnabledReminders();
    }

    if (!mounted) {
      return;
    }

    setState(() {});

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text('${row.title} deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            await _editor.undo(token);

            if (!mounted) {
              return;
            }

            if (value is Reminder) {
              await ReminderRepository(
                widget.database,
              ).rescheduleEnabledReminders();

              if (!mounted) {
                return;
              }
            }

            setState(() {});
          },
        ),
      ),
    );
  }

  Future<bool> _editFood(FoodEntry r) async {
    final name = TextEditingController(text: r.name);
    final kcal = TextEditingController(text: r.calories.toString());
    final p = TextEditingController(text: (r.proteinG ?? 0).toString());
    final c = TextEditingController(text: (r.carbsG ?? 0).toString());
    final f = TextEditingController(text: (r.fatG ?? 0).toString());
    final ok = await _form(
      'Edit food',
      <Widget>[
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        TextField(
          controller: kcal,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Calories'),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: p,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Protein'),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: TextField(
                controller: c,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Carbs'),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: TextField(
                controller: f,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Fat'),
              ),
            ),
          ],
        ),
      ],
      () => _editor.updateFood(
        r,
        name: name.text,
        calories: double.parse(kcal.text),
        proteinG: double.parse(p.text),
        carbsG: double.parse(c.text),
        fatG: double.parse(f.text),
      ),
    );
    name.dispose();
    kcal.dispose();
    p.dispose();
    c.dispose();
    f.dispose();
    return ok;
  }

  Future<bool> _editActivity(ActivityEntry r) async {
    final type = TextEditingController(text: r.activityType);
    final intensity = TextEditingController(text: r.intensity);
    final minutes = TextEditingController(text: r.durationMinutes.toString());
    final distance = TextEditingController(
      text: r.distanceKm?.toString() ?? '',
    );
    final kcal = TextEditingController(text: r.caloriesBurned.toString());
    final ok = await _form(
      'Edit activity',
      <Widget>[
        TextField(
          controller: type,
          decoration: const InputDecoration(labelText: 'Activity'),
        ),
        TextField(
          controller: intensity,
          decoration: const InputDecoration(labelText: 'Intensity'),
        ),
        TextField(
          controller: minutes,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutes'),
        ),
        TextField(
          controller: distance,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Distance km (optional)',
          ),
        ),
        TextField(
          controller: kcal,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Estimated calories'),
        ),
      ],
      () => _editor.updateActivity(
        r,
        type: type.text,
        intensity: intensity.text,
        minutes: int.parse(minutes.text),
        distanceKm: distance.text.trim().isEmpty
            ? null
            : double.parse(distance.text),
        calories: double.parse(kcal.text),
      ),
    );
    type.dispose();
    intensity.dispose();
    minutes.dispose();
    distance.dispose();
    kcal.dispose();
    return ok;
  }

  Future<bool> _editWater(WaterEntry r) async {
    final ml = TextEditingController(text: r.amountMl.toString());
    final ok = await _form('Edit water', <Widget>[
      TextField(
        controller: ml,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Amount ml'),
      ),
    ], () => _editor.updateWater(r, int.parse(ml.text)));
    ml.dispose();
    return ok;
  }

  Future<bool> _editStudy(StudySession r) async {
    final subject = TextEditingController(text: r.subject);
    final mins = TextEditingController(
      text: (r.durationSeconds / 60).round().toString(),
    );
    final notes = TextEditingController(text: r.notes ?? '');
    final ok = await _form(
      'Edit study session',
      <Widget>[
        TextField(
          controller: subject,
          decoration: const InputDecoration(labelText: 'Subject'),
        ),
        TextField(
          controller: mins,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutes'),
        ),
        TextField(
          controller: notes,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
      ],
      () => _editor.updateStudy(
        r,
        subject: subject.text,
        durationMinutes: int.parse(mins.text),
        notes: notes.text,
      ),
    );
    subject.dispose();
    mins.dispose();
    notes.dispose();
    return ok;
  }

  Future<bool> _editWeight(WeightEntry r) async {
    final kg = TextEditingController(text: r.weightKg.toString());
    final note = TextEditingController(text: r.note ?? '');
    final ok = await _form('Edit weight', <Widget>[
      TextField(
        controller: kg,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Weight kg'),
      ),
      TextField(
        controller: note,
        decoration: const InputDecoration(labelText: 'Note'),
      ),
    ], () => _editor.updateWeight(r, double.parse(kg.text), note.text));
    kg.dispose();
    note.dispose();
    return ok;
  }

  Future<bool> _editGoal(Goal r) async {
    final title = TextEditingController(text: r.title);
    final category = TextEditingController(text: r.category);
    final frequency = TextEditingController(text: r.frequency);
    bool active = r.active;
    final ok = await _form(
      'Edit goal',
      <Widget>[
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        TextField(
          controller: category,
          decoration: const InputDecoration(labelText: 'Category'),
        ),
        TextField(
          controller: frequency,
          decoration: const InputDecoration(labelText: 'Frequency'),
        ),
        StatefulBuilder(
          builder: (context, setState) => SwitchListTile(
            value: active,
            onChanged: (v) => setState(() => active = v),
            title: const Text('Active'),
          ),
        ),
      ],
      () => _editor.updateGoal(
        r,
        title: title.text,
        category: category.text,
        frequency: frequency.text,
        active: active,
      ),
    );
    title.dispose();
    category.dispose();
    frequency.dispose();
    return ok;
  }

  Future<bool> _editRoutine(RoutineItem r) async {
    final title = TextEditingController(text: r.title);
    final type = TextEditingController(text: r.routineType);
    final order = TextEditingController(text: r.sortOrder.toString());
    bool active = r.active;
    final ok = await _form(
      'Edit routine',
      <Widget>[
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        TextField(
          controller: type,
          decoration: const InputDecoration(labelText: 'Routine type'),
        ),
        TextField(
          controller: order,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Sort order'),
        ),
        StatefulBuilder(
          builder: (context, setState) => SwitchListTile(
            value: active,
            onChanged: (v) => setState(() => active = v),
            title: const Text('Active'),
          ),
        ),
      ],
      () => _editor.updateRoutine(
        r,
        title: title.text,
        routineType: type.text,
        sortOrder: int.parse(order.text),
        active: active,
      ),
    );
    title.dispose();
    type.dispose();
    order.dispose();
    return ok;
  }

  Future<bool> _editReminder(Reminder r) async {
    final title = TextEditingController(text: r.title);
    final body = TextEditingController(text: r.body);
    final hour = TextEditingController(text: r.hour.toString());
    final minute = TextEditingController(text: r.minute.toString());
    bool enabled = r.enabled;
    final ok = await _form(
      'Edit reminder',
      <Widget>[
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        TextField(
          controller: body,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: hour,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Hour'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: minute,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minute'),
              ),
            ),
          ],
        ),
        StatefulBuilder(
          builder: (context, setState) => SwitchListTile(
            value: enabled,
            onChanged: (v) => setState(() => enabled = v),
            title: const Text('Enabled'),
          ),
        ),
      ],
      () async {
        await _editor.updateReminder(
          r,
          title: title.text,
          body: body.text,
          hour: int.parse(hour.text),
          minute: int.parse(minute.text),
          enabled: enabled,
        );
        await ReminderRepository(widget.database).rescheduleEnabledReminders();
      },
    );
    title.dispose();
    body.dispose();
    hour.dispose();
    minute.dispose();
    return ok;
  }

  Future<bool> _form(
    String title,
    List<Widget> fields,
    Future<void> Function() save,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 14),
              for (final field in fields) ...<Widget>[
                field,
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      await save();

                      if (!sheetContext.mounted) {
                        return;
                      }

                      Navigator.of(sheetContext).pop(true);
                    } catch (error) {
                      if (!sheetContext.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(
                          content: Text('Could not save: $error'),
                        ),
                      );
                    }
                  },
                  child: const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return result == true;
  }
}

class _Row {
  const _Row(this.value, this.title, this.subtitle);
  final Object value;
  final String title;
  final String subtitle;
}
