import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/data_export_service.dart';
import '../../../core/services/data_import_service.dart';
import '../../../core/services/privacy_service.dart';
import '../../../core/theme/pr_theme.dart';
import '../../../core/widgets/premium_panel.dart';
import '../../reminders/data/reminder_repository.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({required this.database, super.key});

  final AppDatabase database;

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _working = false;
  String? _message;

  Future<void> _backup() async {
    if (_working) return;
    setState(() {
      _working = true;
      _message = null;
    });

    try {
      final File file = await DataExportService(widget.database).exportJson();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _message = 'Backup created at:\n${file.path}');
    } catch (error) {
      if (mounted) setState(() => _message = 'Backup failed: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restore() async {
    if (_working) return;

    final bool supported = await PrivacyService.instance
        .deviceAuthenticationSupported();
    if (supported) {
      final bool authenticated = await PrivacyService.instance.authenticate(
        reason: 'Authenticate before restoring PrFitness data.',
      );
      if (!authenticated) return;
    }

    const XTypeGroup group = XTypeGroup(
      label: 'PrFitness JSON backup',
      extensions: <String>['json'],
      mimeTypes: <String>['application/json'],
    );

    final XFile? selected = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[group],
    );
    if (selected == null || !mounted) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'Current local PrFitness tracking data will be replaced by the selected backup. Cloud credentials are not imported.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _working = true;
      _message = null;
    });

    try {
      final String source = await selected.readAsString();
      final ImportSummary summary = await DataImportService(widget.database)
          .restoreJson(source);
      await ReminderRepository(widget.database).rescheduleEnabledReminders();
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(
        () => _message =
            'Restore complete • ${summary.records} record(s) loaded.',
      );
    } catch (error) {
      if (mounted) setState(() => _message = 'Restore rejected: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Backup & Restore'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: <Widget>[
          PremiumPanel(
            borderRadius: 34,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.inventory_2_rounded, color: accent),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Your data stays portable',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Create a complete JSON backup or restore one through the native Android / Windows file picker.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PremiumPanel(
            child: Column(
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton.icon(
                    onPressed: _working ? null : _backup,
                    icon: const Icon(Icons.backup_rounded),
                    label: const Text('Create backup'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: _working ? null : _restore,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Restore JSON backup'),
                  ),
                ),
              ],
            ),
          ),
          if (_message != null) ...<Widget>[
            const SizedBox(height: 16),
            PremiumPanel(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.info_outline_rounded, color: accent),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_message!)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const PremiumPanel(
            child: Text(
              'Restore validates the PrFitness backup format and version before replacing local tracking records. Authentication tokens and cloud account ownership are deliberately excluded.',
            ),
          ),
        ],
      ),
    );
  }
}
