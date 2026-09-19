import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/pr_theme.dart';
import '../../core/widgets/premium_backdrop.dart';
import '../dashboard/dashboard_screen.dart';
import '../health/health_hub_screen.dart';
import '../more/control_screen.dart';
import 'module_screen.dart';

enum PrSection { dashboard, health, study, goals, control }

class PrFitnessShell extends StatefulWidget {
  const PrFitnessShell({
    required this.database,
    required this.profile,
    required this.blackGold,
    required this.onToggleTheme,
    required this.onProfileUpdated,
    super.key,
  });

  final AppDatabase database;
  final ProfileRow profile;
  final bool blackGold;
  final VoidCallback onToggleTheme;
  final ValueChanged<ProfileRow> onProfileUpdated;

  @override
  State<PrFitnessShell> createState() => _PrFitnessShellState();
}

class _PrFitnessShellState extends State<PrFitnessShell> {
  PrSection _section = PrSection.dashboard;

  void _select(PrSection value) {
    if (value == _section) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _section = value;
    });
  }

  Widget _screen() {
    return switch (_section) {
      PrSection.dashboard => DashboardScreen(
        database: widget.database,
        profile: widget.profile,
      ),
      PrSection.health => HealthHubScreen(
        database: widget.database,
        profile: widget.profile,
      ),
      PrSection.study => const ModuleScreen(
        title: 'Study Intelligence',
        subtitle: 'Focus sessions, timestamps and performance intelligence.',
        icon: Icons.school_rounded,
        features: <String>[
          'Live focus timer',
          'Timestamped sessions',
          'Subject analytics',
          'Daily study target',
          'Consistency intelligence',
        ],
      ),
      PrSection.goals => const ModuleScreen(
        title: 'Goals & Routines',
        subtitle: 'Build measurable execution across your day.',
        icon: Icons.task_alt_rounded,
        features: <String>[
          'Daily checklist',
          'Custom routines',
          'Goal streaks',
          'Local reminders',
          'Completion analytics',
        ],
      ),
      PrSection.control => ControlScreen(
        database: widget.database,
        profile: widget.profile,
        onProfileUpdated: widget.onProfileUpdated,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackdrop(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool desktop = constraints.maxWidth >= 920;

            if (desktop) {
              return SafeArea(
                child: Row(
                  children: <Widget>[
                    _DesktopNavigation(
                      current: _section,
                      blackGold: widget.blackGold,
                      onSelect: _select,
                      onToggleTheme: widget.onToggleTheme,
                    ),
                    Expanded(
                      child: _AnimatedBody(section: _section, child: _screen()),
                    ),
                  ],
                ),
              );
            }

            return SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  _MobileHeader(
                    blackGold: widget.blackGold,
                    onToggleTheme: widget.onToggleTheme,
                  ),
                  Expanded(
                    child: _AnimatedBody(section: _section, child: _screen()),
                  ),
                  _MobileNavigation(current: _section, onSelect: _select),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedBody extends StatelessWidget {
  const _AnimatedBody({required this.section, required this.child});

  final PrSection section;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 430),
      reverseDuration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.045, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey<PrSection>(section), child: child),
    );
  }
}

const List<({PrSection section, String label, IconData icon})>
_destinations = <({PrSection section, String label, IconData icon})>[
  (section: PrSection.dashboard, label: 'Home', icon: Icons.dashboard_rounded),
  (section: PrSection.health, label: 'Health', icon: Icons.favorite_rounded),
  (section: PrSection.study, label: 'Study', icon: Icons.school_rounded),
  (section: PrSection.goals, label: 'Goals', icon: Icons.task_alt_rounded),
  (section: PrSection.control, label: 'Control', icon: Icons.grid_view_rounded),
];

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.current,
    required this.blackGold,
    required this.onSelect,
    required this.onToggleTheme,
  });

  final PrSection current;
  final bool blackGold;
  final ValueChanged<PrSection> onSelect;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return Container(
      width: 258,
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PrTheme.isBlackGold(context)
            ? const Color(0xE3121214)
            : const Color(0xF5FFFFFF),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: accent.withAlpha(32)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withAlpha(
              PrTheme.isBlackGold(context) ? 90 : 14,
            ),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 6),
          _Brand(accent: accent),
          const SizedBox(height: 30),
          for (final destination in _destinations)
            _DesktopItem(
              destination: destination,
              selected: current == destination.section,
              onTap: () => onSelect(destination.section),
            ),
          const Spacer(),
          _ThemeSwitch(
            blackGold: blackGold,
            onTap: onToggleTheme,
            showLabel: true,
          ),
        ],
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.blackGold, required this.onToggleTheme});

  final bool blackGold;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 11, 12, 3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _Brand(accent: PrTheme.accent(context), compact: true),
          ),
          _ThemeSwitch(
            blackGold: blackGold,
            onTap: onToggleTheme,
            showLabel: false,
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.accent, this.compact = false});

  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: compact ? 42 : 48,
          height: compact ? 42 : 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[accent, PrTheme.secondaryAccent(context)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(color: accent.withAlpha(70), blurRadius: 20),
            ],
          ),
          child: Icon(
            Icons.bolt_rounded,
            color: PrTheme.isBlackGold(context) ? Colors.black : Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'PrFitness',
          style: TextStyle(
            fontSize: compact ? 20 : 23,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );
  }
}

class _DesktopItem extends StatelessWidget {
  const _DesktopItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ({PrSection section, String label, IconData icon}) destination;

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? accent.withAlpha(22) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? accent.withAlpha(48) : Colors.transparent,
            ),
          ),
          child: Row(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected ? accent : accent.withAlpha(12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  destination.icon,
                  size: 20,
                  color: selected
                      ? PrTheme.isBlackGold(context)
                            ? Colors.black
                            : Colors.white
                      : accent,
                ),
              ),
              const SizedBox(width: 11),
              Text(
                destination.label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({required this.current, required this.onSelect});

  final PrSection current;
  final ValueChanged<PrSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        7,
        7,
        7,
        MediaQuery.paddingOf(context).bottom + 6,
      ),
      decoration: BoxDecoration(
        color: PrTheme.isBlackGold(context)
            ? const Color(0xF50C0C0D)
            : const Color(0xFAFFFFFF),
        border: Border(
          top: BorderSide(color: PrTheme.accent(context).withAlpha(24)),
        ),
      ),
      child: Row(
        children: <Widget>[
          for (final destination in _destinations)
            Expanded(
              child: _MobileItem(
                destination: destination,
                selected: current == destination.section,
                onTap: () => onSelect(destination.section),
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileItem extends StatelessWidget {
  const _MobileItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ({PrSection section, String label, IconData icon}) destination;

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withAlpha(18) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedScale(
              scale: selected ? 1.14 : 1,
              duration: const Duration(milliseconds: 240),
              child: Icon(
                destination.icon,
                size: 22,
                color: selected
                    ? accent
                    : Theme.of(context).colorScheme.onSurface.withAlpha(125),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              style: TextStyle(
                fontSize: 9.8,
                color: selected
                    ? accent
                    : Theme.of(context).colorScheme.onSurface.withAlpha(125),
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwitch extends StatelessWidget {
  const _ThemeSwitch({
    required this.blackGold,
    required this.onTap,
    required this.showLabel,
  });

  final bool blackGold;
  final VoidCallback onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: accent.withAlpha(18),
          border: Border.all(color: accent.withAlpha(40)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                blackGold ? Icons.diamond_rounded : Icons.auto_awesome_rounded,
                key: ValueKey<bool>(blackGold),
                color: accent,
                size: 19,
              ),
            ),
            if (showLabel) ...<Widget>[
              const SizedBox(width: 8),
              Text(
                blackGold ? 'Black & Gold' : 'Pink & White',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
