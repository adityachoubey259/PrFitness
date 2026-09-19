import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/pr_theme.dart';
import '../../core/widgets/premium_panel.dart';
import '../productivity/data/productivity_repository.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({required this.database, required this.profile, super.key});

  final AppDatabase database;
  final ProfileRow profile;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final TextEditingController _subject = TextEditingController(
    text: 'Focus Session',
  );

  DateTime? _startedAt;
  Timer? _ticker;

  Duration _elapsed = Duration.zero;

  bool get _running => _startedAt != null;

  @override
  void initState() {
    super.initState();

    unawaited(_restoreActiveSession());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _subject.dispose();

    super.dispose();
  }

  Future<void> _restoreActiveSession() async {
    final String? started = await widget.database.readSetting(
      'study_active_started_at',
    );

    final String? subject = await widget.database.readSetting(
      'study_active_subject',
    );

    if (started == null) {
      return;
    }

    final DateTime? parsed = DateTime.tryParse(started);

    if (parsed == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _startedAt = parsed;
      _subject.text = subject ?? 'Focus Session';
      _updateElapsed();
    });

    _startTicker();
  }

  Future<void> _start() async {
    if (_running) {
      return;
    }

    final String subject = _subject.text.trim();

    if (subject.isEmpty) {
      return;
    }

    final DateTime now = DateTime.now();

    await widget.database.writeSetting(
      'study_active_started_at',
      now.toIso8601String(),
    );

    await widget.database.writeSetting('study_active_subject', subject);

    if (!mounted) {
      return;
    }

    setState(() {
      _startedAt = now;
      _elapsed = Duration.zero;
    });

    HapticFeedback.mediumImpact();

    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(_updateElapsed);
    });
  }

  void _updateElapsed() {
    if (_startedAt == null) {
      _elapsed = Duration.zero;
      return;
    }

    _elapsed = DateTime.now().difference(_startedAt!);
  }

  Future<void> _stop() async {
    final DateTime? start = _startedAt;

    if (start == null) {
      return;
    }

    final DateTime end = DateTime.now();

    if (end.difference(start).inSeconds > 0) {
      await ProductivityRepository(
        widget.database,
      ).addStudySession(subject: _subject.text, startedAt: start, endedAt: end);
    }

    await widget.database.deleteSetting('study_active_started_at');

    await widget.database.deleteSetting('study_active_subject');

    _ticker?.cancel();

    if (!mounted) {
      return;
    }

    setState(() {
      _startedAt = null;
      _elapsed = Duration.zero;
    });

    HapticFeedback.heavyImpact();
  }

  String _clock(Duration duration) {
    final int hours = duration.inHours;

    final int minutes = duration.inMinutes % 60;

    final int seconds = duration.inSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.now();

    return StreamBuilder<List<StudySession>>(
      stream: widget.database.watchStudyForDay(today),
      builder:
          (BuildContext context, AsyncSnapshot<List<StudySession>> snapshot) {
            final List<StudySession> sessions =
                snapshot.data ?? <StudySession>[];

            final int loggedSeconds = sessions.fold<int>(
              0,
              (int sum, StudySession item) => sum + item.durationSeconds,
            );

            final int liveSeconds = _running ? _elapsed.inSeconds : 0;

            final int totalMinutes = ((loggedSeconds + liveSeconds) / 60)
                .floor();

            return _buildBody(
              context,
              sessions: sessions,
              totalMinutes: totalMinutes,
            );
          },
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required List<StudySession> sessions,
    required int totalMinutes,
  }) {
    final Color accent = PrTheme.accent(context);

    final int target = widget.profile.dailyStudyTargetMinutes;

    final double progress = target <= 0
        ? 0
        : (totalMinutes / target).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
      children: <Widget>[
        Text(
          'Study Intelligence',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1),
        ),
        const SizedBox(height: 5),
        const Text('Deep work measured by real timestamps.'),
        const SizedBox(height: 22),

        PremiumPanel(
          borderRadius: 36,
          child: Column(
            children: <Widget>[
              SizedBox(
                width: 190,
                height: 190,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(begin: 0, end: progress),
                        builder:
                            (
                              BuildContext context,
                              double value,
                              Widget? child,
                            ) {
                              return CircularProgressIndicator(
                                value: value,
                                strokeWidth: 10,
                                strokeCap: StrokeCap.round,
                                backgroundColor: accent.withAlpha(16),
                              );
                            },
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _running ? _clock(_elapsed) : '$totalMinutes',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          _running ? 'FOCUS LIVE' : 'MIN TODAY',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _subject,
                enabled: !_running,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Current subject / mission',
                  prefixIcon: Icon(Icons.psychology_alt_rounded),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton.icon(
                  onPressed: _running ? _stop : _start,
                  icon: Icon(
                    _running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    _running ? 'Complete focus session' : 'Begin deep focus',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$totalMinutes / $target min target',
                style: TextStyle(color: accent, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          height: 51,
          child: OutlinedButton.icon(
            onPressed: () => _manualEntry(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add previous study session'),
          ),
        ),

        const SizedBox(height: 24),

        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Today’s timeline',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${sessions.length} sessions',
              style: TextStyle(color: accent, fontWeight: FontWeight.w700),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (sessions.isEmpty)
          PremiumPanel(
            child: const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No study session logged yet.'),
              ),
            ),
          )
        else
          PremiumPanel(
            child: Column(
              children: <Widget>[
                for (final StudySession session in sessions)
                  _StudyTimelineRow(session: session),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _manualEntry(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return _ManualStudySheet(
          repository: ProductivityRepository(widget.database),
        );
      },
    );
  }
}

class _ManualStudySheet extends StatefulWidget {
  const _ManualStudySheet({required this.repository});

  final ProductivityRepository repository;

  @override
  State<_ManualStudySheet> createState() => _ManualStudySheetState();
}

class _ManualStudySheetState extends State<_ManualStudySheet> {
  final TextEditingController _subject = TextEditingController();

  final TextEditingController _minutes = TextEditingController();

  @override
  void dispose() {
    _subject.dispose();
    _minutes.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    final int? minutes = int.tryParse(_minutes.text.trim());

    if (_subject.text.trim().isEmpty || minutes == null || minutes <= 0) {
      return;
    }

    await widget.repository.addManualStudy(
      subject: _subject.text,
      minutes: minutes,
    );

    if (mounted) {
      Navigator.of(context).pop();
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
          TextField(
            controller: _subject,
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minutes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Duration',
              suffixText: 'minutes',
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save session'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyTimelineRow extends StatelessWidget {
  const _StudyTimelineRow({required this.session});

  final StudySession session;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    final int minutes = (session.durationSeconds / 60).round();

    String time(DateTime value) {
      final int hour = value.hour;
      final int minute = value.minute;

      return '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              boxShadow: <BoxShadow>[
                BoxShadow(color: accent.withAlpha(90), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  session.subject,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${time(session.startedAt)} → '
                  '${time(session.endedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '$minutes min',
            style: TextStyle(color: accent, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
