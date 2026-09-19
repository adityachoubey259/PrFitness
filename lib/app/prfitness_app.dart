import 'dart:async';

import 'package:flutter/material.dart';

import '../core/database/app_database.dart';
import '../core/theme/pr_theme.dart';
import '../features/profile/presentation/profile_setup_screen.dart';
import '../features/reminders/data/reminder_repository.dart';
import '../features/shell/prfitness_shell.dart';

class PrFitnessApp extends StatefulWidget {
  const PrFitnessApp({super.key, this.database});

  final AppDatabase? database;

  @override
  State<PrFitnessApp> createState() => _PrFitnessAppState();
}

class _PrFitnessAppState extends State<PrFitnessApp> {
  late final AppDatabase _database;
  late final bool _ownsDatabase;

  bool _loading = true;
  bool _blackGold = false;

  ProfileRow? _profile;

  @override
  void initState() {
    super.initState();

    _ownsDatabase = widget.database == null;

    _database = widget.database ?? AppDatabase();

    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final String? theme = await _database.readSetting('theme');

    final ProfileRow? profile = await _database.getProfile();

    await ReminderRepository(_database).rescheduleEnabledReminders();

    if (!mounted) {
      return;
    }

    setState(() {
      _blackGold = theme == 'black_gold';

      _profile = profile;
      _loading = false;
    });
  }

  void _toggleTheme() {
    setState(() {
      _blackGold = !_blackGold;
    });

    unawaited(
      _database.writeSetting('theme', _blackGold ? 'black_gold' : 'pink_white'),
    );
  }

  void _profileUpdated(ProfileRow profile) {
    setState(() {
      _profile = profile;
    });
  }

  @override
  void dispose() {
    if (_ownsDatabase) {
      unawaited(_database.close());
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrFitness',
      debugShowCheckedModeBanner: false,
      theme: PrTheme.pinkWhite(),
      darkTheme: PrTheme.blackGold(),
      themeMode: _blackGold ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: const Duration(milliseconds: 650),
      home: _loading
          ? const _BootScreen()
          : _profile == null
          ? ProfileSetupScreen(
              database: _database,
              onCompleted: _profileUpdated,
            )
          : PrFitnessShell(
              database: _database,
              profile: _profile!,
              blackGold: _blackGold,
              onToggleTheme: _toggleTheme,
              onProfileUpdated: _profileUpdated,
            ),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 900),
          tween: Tween<double>(begin: 0.7, end: 1),
          curve: Curves.easeOutBack,
          builder: (BuildContext context, double value, Widget? child) {
            return Transform.scale(scale: value, child: child);
          },
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[PrColors.pinkPrimary, PrColors.pinkSecondary],
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
        ),
      ),
    );
  }
}
