import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/pr_theme.dart';
import '../../../core/widgets/premium_panel.dart';
import '../data/reminder_repository.dart';
import '../domain/reminder_rules.dart';

class ReminderCenterScreen extends StatefulWidget {
  const ReminderCenterScreen({required this.database, super.key});

  final AppDatabase database;

  @override
  State<ReminderCenterScreen> createState() => _ReminderCenterScreenState();
}

class _ReminderCenterScreenState extends State<ReminderCenterScreen> {
  bool _notificationsEnabled = false;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _refreshSystemState();
  }

  Future<void> _refreshSystemState() async {
    final bool enabled = await NotificationService.instance
        .notificationsEnabled();

    final int pending = await NotificationService.instance.pendingCount();

    if (!mounted) {
      return;
    }

    setState(() {
      _notificationsEnabled = enabled;
      _pending = pending;
    });
  }

  Future<void> _requestPermission() async {
    final bool granted = await NotificationService.instance.requestPermission();

    if (!mounted) {
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _notificationsEnabled = granted;
    });

    await _refreshSystemState();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Reminder Intelligence'),
      ),
      body: StreamBuilder<List<Reminder>>(
        stream: widget.database.watchReminders(),
        builder:
            (BuildContext context, AsyncSnapshot<List<Reminder>> snapshot) {
              final List<Reminder> reminders = snapshot.data ?? <Reminder>[];

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                children: <Widget>[
                  PremiumPanel(
                    borderRadius: 34,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: accent.withAlpha(18),
                                borderRadius: BorderRadius.circular(19),
                              ),
                              child: Icon(
                                Icons.notifications_active_rounded,
                                color: accent,
                                size: 29,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Local intelligence',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'No cloud is required to remind you.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _StatusPill(
                                label: _notificationsEnabled
                                    ? 'Notifications ON'
                                    : 'Permission needed',
                                positive: _notificationsEnabled,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatusPill(
                                label: '$_pending scheduled',
                                positive: true,
                              ),
                            ),
                          ],
                        ),
                        if (!_notificationsEnabled) ...<Widget>[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _requestPermission,
                              icon: const Icon(Icons.notifications_rounded),
                              label: const Text('Enable notifications'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Your reminders',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: () => _createReminder(context),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (reminders.isEmpty)
                    PremiumPanel(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Column(
                          children: <Widget>[
                            Icon(
                              Icons.notifications_none_rounded,
                              size: 42,
                              color: accent,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No reminders yet',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Create reminders for water, study, goals and routines.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final Reminder reminder in reminders)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReminderCard(
                          reminder: reminder,
                          repository: ReminderRepository(widget.database),
                          onChanged: _refreshSystemState,
                        ),
                      ),
                ],
              );
            },
      ),
    );
  }

  Future<void> _createReminder(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return _ReminderEditor(
          repository: ReminderRepository(widget.database),
          onCreated: _refreshSystemState,
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: accent.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withAlpha(positive ? 34 : 18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            positive ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 15,
            color: accent,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.repository,
    required this.onChanged,
  });

  final Reminder reminder;
  final ReminderRepository repository;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return PremiumPanel(
      borderRadius: 25,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: reminder.enabled
                  ? accent.withAlpha(20)
                  : Theme.of(context).colorScheme.onSurface.withAlpha(8),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              _categoryIcon(reminder.category),
              color: reminder.enabled
                  ? accent
                  : Theme.of(context).colorScheme.onSurface.withAlpha(90),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  reminder.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  _scheduleText(reminder),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  reminder.category,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: reminder.enabled,
            onChanged: (bool value) async {
              HapticFeedback.selectionClick();

              await repository.setEnabled(reminder: reminder, enabled: value);

              onChanged();
            },
          ),
          IconButton(
            tooltip: 'Delete reminder',
            onPressed: () async {
              await repository.delete(reminder);

              onChanged();
            },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  static IconData _categoryIcon(String value) {
    return switch (value) {
      'Water' => Icons.water_drop_rounded,
      'Study' => Icons.school_rounded,
      'Fitness' => Icons.directions_run_rounded,
      'Routine' => Icons.checklist_rounded,
      'Goal' => Icons.flag_rounded,
      _ => Icons.notifications_rounded,
    };
  }

  static String _scheduleText(Reminder reminder) {
    String time() =>
        '${reminder.hour.toString().padLeft(2, '0')}:'
        '${reminder.minute.toString().padLeft(2, '0')}';

    if (reminder.scheduleType == 'one_time' && reminder.scheduledAt != null) {
      final DateTime value = reminder.scheduledAt!;

      return '${value.day.toString().padLeft(2, '0')}/'
          '${value.month.toString().padLeft(2, '0')}/'
          '${value.year} • ${time()}';
    }

    if (reminder.scheduleType == 'weekdays') {
      const List<String> names = <String>[
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ];

      final List<String> selected = ReminderRules.daysFromMask(
        reminder.weekdaysMask,
      ).map((int day) => names[day - 1]).toList();

      return '${selected.join(', ')} • ${time()}';
    }

    return 'Every day • ${time()}';
  }
}

class _ReminderEditor extends StatefulWidget {
  const _ReminderEditor({required this.repository, required this.onCreated});

  final ReminderRepository repository;
  final VoidCallback onCreated;

  @override
  State<_ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<_ReminderEditor> {
  final TextEditingController _title = TextEditingController();

  final TextEditingController _body = TextEditingController();

  String _category = 'Personal';
  String _scheduleType = 'daily';

  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);

  DateTime _oneTimeDate = DateTime.now().add(const Duration(days: 1));

  final Set<int> _days = <int>{1, 2, 3, 4, 5};

  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();

    super.dispose();
  }

  Future<void> _pickTime() async {
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: _time,
    );

    if (selected != null && mounted) {
      setState(() {
        _time = selected;
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();

    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _oneTimeDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );

    if (selected != null && mounted) {
      setState(() {
        _oneTimeDate = selected;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    DateTime? oneTime;

    if (_scheduleType == 'one_time') {
      oneTime = DateTime(
        _oneTimeDate.year,
        _oneTimeDate.month,
        _oneTimeDate.day,
        _time.hour,
        _time.minute,
      );
    }

    final int mask = ReminderRules.maskFromDays(
      _scheduleType == 'weekdays' ? _days : <int>[1, 2, 3, 4, 5, 6, 7],
    );

    try {
      ReminderRules.validate(
        title: _title.text,
        scheduleType: _scheduleType,
        hour: _time.hour,
        minute: _time.minute,
        weekdaysMask: mask,
        scheduledAt: oneTime,
      );
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message.toString())));

      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.repository.create(
        title: _title.text,
        body: _body.text,
        category: _category,
        scheduleType: _scheduleType,
        hour: _time.hour,
        minute: _time.minute,
        weekdaysMask: mask,
        scheduledAt: oneTime,
      );

      HapticFeedback.mediumImpact();

      widget.onCreated();

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
    final Color accent = PrTheme.accent(context);

    const List<(int, String)> weekdays = <(int, String)>[
      (1, 'M'),
      (2, 'T'),
      (3, 'W'),
      (4, 'T'),
      (5, 'F'),
      (6, 'S'),
      (7, 'S'),
    ];

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
              'Create reminder',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text(
              'Schedule locally. Your reminder does not depend on a server.',
            ),
            const SizedBox(height: 18),

            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Reminder title',
                prefixIcon: Icon(Icons.notifications_none_rounded),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _body,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Message (optional)',
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items:
                  const <String>[
                        'Personal',
                        'Water',
                        'Study',
                        'Fitness',
                        'Routine',
                        'Goal',
                      ]
                      .map(
                        (String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _category = value;
                });
              },
            ),

            const SizedBox(height: 16),

            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'daily',
                  icon: Icon(Icons.repeat_rounded),
                  label: Text('Daily'),
                ),
                ButtonSegment<String>(
                  value: 'weekdays',
                  icon: Icon(Icons.date_range_rounded),
                  label: Text('Days'),
                ),
                ButtonSegment<String>(
                  value: 'one_time',
                  icon: Icon(Icons.event_rounded),
                  label: Text('Once'),
                ),
              ],
              selected: <String>{_scheduleType},
              onSelectionChanged: (Set<String> value) {
                setState(() {
                  _scheduleType = value.first;
                });
              },
            ),

            if (_scheduleType == 'weekdays') ...<Widget>[
              const SizedBox(height: 16),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: weekdays.map(((int, String) item) {
                  final bool selected = _days.contains(item.$1);

                  return ChoiceChip(
                    label: Text(item.$2),
                    selected: selected,
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          _days.add(item.$1);
                        } else {
                          _days.remove(item.$1);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],

            if (_scheduleType == 'one_time') ...<Widget>[
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                  child: Text(
                    '${_oneTimeDate.day.toString().padLeft(2, '0')}/'
                    '${_oneTimeDate.month.toString().padLeft(2, '0')}/'
                    '${_oneTimeDate.year}',
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: _pickTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Time',
                  prefixIcon: Icon(Icons.schedule_rounded),
                ),
                child: Text(
                  _time.format(context),
                  style: TextStyle(color: accent, fontWeight: FontWeight.w900),
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.notifications_active_rounded),
                label: Text(_saving ? 'Scheduling...' : 'Activate reminder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
