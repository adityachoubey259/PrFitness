import '../food/presentation/food_intelligence_screen.dart';
import '../history/presentation/data_management_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/pr_theme.dart';
import '../../core/widgets/premium_panel.dart';
import '../analytics/presentation/analytics_screen.dart';
import '../history/presentation/history_vault_plus_screen.dart';
import '../privacy/presentation/privacy_center_screen.dart';
import '../profile/domain/body_metrics.dart';
import '../profile/presentation/profile_setup_screen.dart';
import '../reminders/presentation/reminder_center_screen.dart';
import '../sync/presentation/account_sync_screen.dart';
import '../backup/presentation/backup_restore_screen.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({
    required this.database,
    required this.profile,
    required this.onProfileUpdated,
    super.key,
  });

  final AppDatabase database;
  final ProfileRow profile;

  final ValueChanged<ProfileRow> onProfileUpdated;

  Future<void> _editProfile(BuildContext context) async {
    await Navigator.of(context).push(
      _premiumRoute(
        ProfileSetupScreen(
          database: database,
          existing: profile,
          onCompleted: (ProfileRow updated) {
            onProfileUpdated(updated);

            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Route<void> _premiumRoute(Widget child) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 430),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) => child,
      transitionsBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            final CurvedAnimation curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    final BodyMetricsSnapshot metrics = BodyMetrics.evaluate(
      birthDate: profile.birthDate,
      sex: profile.sex,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      activityLevel: profile.activityLevel,
      goal: profile.goal,
    );

    final Color accent = PrTheme.accent(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
      children: <Widget>[
        Text(
          'Control Center',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1),
        ),

        const SizedBox(height: 5),

        const Text('Your identity, intelligence, privacy and data controls.'),

        const SizedBox(height: 22),

        PremiumPanel(
          borderRadius: 34,
          child: Column(
            children: <Widget>[
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: <Color>[accent, PrTheme.secondaryAccent(context)],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: accent.withAlpha(70), blurRadius: 26),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  profile.name.trim().isEmpty
                      ? 'P'
                      : profile.name.trim()[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Text(
                profile.name,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${metrics.age} years Ã¢â‚¬Â¢ '
                '${profile.heightCm.toStringAsFixed(0)} cm Ã¢â‚¬Â¢ '
                '${profile.weightKg.toStringAsFixed(1)} kg',
              ),
              const SizedBox(height: 17),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();

                    _editProfile(context);
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Refine baseline'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        Text(
          'Intelligence',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: 10),

        _Portal(
          icon: Icons.notifications_active_rounded,
          title: 'Reminder Intelligence',
          subtitle: 'Local schedules Ã¢â‚¬Â¢ custom days Ã¢â‚¬Â¢ one-time',
          onTap: () {
            HapticFeedback.selectionClick();

            Navigator.of(context)
                .push(_premiumRoute(ReminderCenterScreen(database: database)));
          },
        ),

        const SizedBox(height: 10),

        _Portal(
          icon: Icons.insights_rounded,
          title: 'Analytics Cockpit',
          subtitle: 'Trends Ã¢â‚¬Â¢ streaks Ã¢â‚¬Â¢ heatmaps Ã¢â‚¬Â¢ personal records',
          onTap: () {
            HapticFeedback.selectionClick();

            Navigator.of(context).push(
              _premiumRoute(
                AnalyticsScreen(database: database, profile: profile),
              ),
            );
          },
        ),

        const SizedBox(height: 10),

        _Portal(
          icon: Icons.history_rounded,
          title: 'History Vault',
          subtitle:
              '90-day timeline Ã¢â‚¬Â¢ body progress Ã¢â‚¬Â¢ record control',
          onTap: () {
            HapticFeedback.selectionClick();

            Navigator.of(context).push(
              _premiumRoute(
                HistoryVaultPlusScreen(
                  database: database,
                  profile: profile,
                  onProfileUpdated: onProfileUpdated,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 22),

        Text(
          'Privacy & ownership',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: 10),

        _Portal(
          icon: Icons.shield_rounded,
          title: 'Privacy & Data',
          subtitle: 'Device authentication Ã¢â‚¬Â¢ secure preferences Ã¢â‚¬Â¢ full export',
          onTap: () {
            HapticFeedback.selectionClick();

            Navigator.of(context)
                .push(_premiumRoute(PrivacyCenterScreen(database: database)));
          },
        ),
        const SizedBox(height: 10),

        _Portal(
          icon: Icons.cloud_sync_rounded,
          title: 'Account & Sync',
          subtitle: 'Secure account â€¢ offline outbox â€¢ conflict-safe cloud',
          onTap: () {
            HapticFeedback.selectionClick();

            Navigator.of(context)
                .push(_premiumRoute(AccountSyncScreen(database: database)));
          },
        ),
        const SizedBox(height: 10),

        _Portal(
          icon: Icons.inventory_2_rounded,
          title: 'Backup & Restore',
          subtitle:
              'Portable JSON â€¢ native file picker â€¢ validated restore',
          onTap: () {
            HapticFeedback.selectionClick();

            Navigator.of(context)
                .push(_premiumRoute(BackupRestoreScreen(database: database)));
          },
        ),
        const SizedBox(height: 10),

        _Portal(
          icon: Icons.restaurant_menu_rounded,
          title: 'Food Intelligence',
          subtitle:
              'Offline search • serving accuracy • favourites • custom foods',
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(
              context,
            ).push(_premiumRoute(FoodIntelligenceScreen(database: database)));
          },
        ),

        const SizedBox(height: 10),

        _Portal(
          icon: Icons.edit_note_rounded,
          title: 'Edit & Undo Center',
          subtitle:
              'Correct records • delete safely • undo • sync-aware changes',
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context)
                .push(_premiumRoute(DataManagementScreen(database: database)));
          },
        ),

        const SizedBox(height: 22),

        Text(
          'Architecture',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: 10),

        PremiumPanel(
          child: const Column(
            children: <Widget>[
              _SystemRow(
                icon: Icons.storage_rounded,
                title: 'Offline Core',
                detail: 'SQLite / Drift local-first',
              ),
              _SystemRow(
                icon: Icons.notifications_none_rounded,
                title: 'Local Reminders',
                detail: 'No server required',
              ),
              _SystemRow(
                icon: Icons.security_rounded,
                title: 'Sensitive preferences',
                detail: 'Platform secure storage',
              ),
              _SystemRow(
                icon: Icons.cloud_sync_rounded,
                title: 'Future Sync',
                detail: 'HTTPS Ã¢â€ â€™ Go Ã¢â€ â€™ private PostgreSQL',
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Portal extends StatelessWidget {
  const _Portal({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: PremiumPanel(
          borderRadius: 28,
          padding: const EdgeInsets.all(17),
          child: Row(
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accent.withAlpha(18),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemRow extends StatelessWidget {
  const _SystemRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(icon, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(detail, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!last) Divider(height: 1, color: accent.withAlpha(16)),
      ],
    );
  }
}
