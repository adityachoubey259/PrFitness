import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/data_export_service.dart';
import '../../../core/services/privacy_service.dart';
import '../../../core/theme/pr_theme.dart';
import '../../../core/widgets/premium_panel.dart';

class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({required this.database, super.key});

  final AppDatabase database;

  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  bool _loading = true;
  bool _authSupported = false;
  bool _protectExport = false;
  bool _exporting = false;

  String? _lastExport;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final PrivacyService privacy = PrivacyService.instance;

    final bool supported = await privacy.deviceAuthenticationSupported();

    final bool protected = await privacy.protectExportEnabled();

    if (!mounted) {
      return;
    }

    setState(() {
      _authSupported = supported;
      _protectExport = supported && protected;
      _loading = false;
    });
  }

  Future<void> _setProtection(bool value) async {
    if (value && !_authSupported) {
      return;
    }

    if (value) {
      final bool authenticated = await PrivacyService.instance.authenticate(
        reason: 'Authenticate to protect PrFitness exports.',
      );

      if (!authenticated) {
        return;
      }
    }

    await PrivacyService.instance.setProtectExport(value);

    if (!mounted) {
      return;
    }

    setState(() {
      _protectExport = value;
    });

    HapticFeedback.mediumImpact();
  }

  Future<void> _export() async {
    if (_exporting) {
      return;
    }

    if (_protectExport) {
      final bool authenticated = await PrivacyService.instance.authenticate(
        reason: 'Authenticate to create your PrFitness data export.',
      );

      if (!authenticated) {
        return;
      }
    }

    setState(() {
      _exporting = true;
    });

    try {
      final File file = await DataExportService(widget.database).exportJson();

      if (!mounted) {
        return;
      }

      setState(() {
        _lastExport = file.path;
      });

      HapticFeedback.heavyImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Private data export created.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  Future<void> _copyPath() async {
    final String? value = _lastExport;

    if (value == null) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: value));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Export path copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Privacy & Data'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              children: <Widget>[
                PremiumPanel(
                  borderRadius: 34,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 59,
                        height: 59,
                        decoration: BoxDecoration(
                          color: accent.withAlpha(18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.shield_rounded,
                          color: accent,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Private by architecture',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Core tracking, scoring, reminders and analytics remain local and usable without a cloud account.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                Text(
                  'Export protection',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),

                const SizedBox(height: 10),

                PremiumPanel(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(Icons.fingerprint_rounded, color: accent),
                    title: const Text(
                      'Require device authentication',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      _authSupported
                          ? 'Fingerprint, face or device credential can protect export creation.'
                          : 'Device authentication is unavailable on this system.',
                    ),
                    value: _protectExport,
                    onChanged: _authSupported ? _setProtection : null,
                  ),
                ),

                const SizedBox(height: 22),

                Text(
                  'Data ownership',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),

                const SizedBox(height: 10),

                PremiumPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Complete JSON export',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Exports profile, nutrition, movement, hydration, study, goals, routines, reminders, body-weight history and local preferences.',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: _exporting ? null : _export,
                          icon: const Icon(Icons.file_download_outlined),
                          label: Text(
                            _exporting
                                ? 'Creating export...'
                                : 'Create private export',
                          ),
                        ),
                      ),
                      if (_lastExport != null) ...<Widget>[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accent.withAlpha(10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'Latest export',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _lastExport!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              TextButton.icon(
                                onPressed: _copyPath,
                                icon: const Icon(Icons.content_copy_rounded),
                                label: const Text('Copy path'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                PremiumPanel(
                  child: const Column(
                    children: <Widget>[
                      _PrivacyFact(
                        icon: Icons.storage_rounded,
                        title: 'Primary storage',
                        detail: 'Local SQLite / Drift',
                      ),
                      _PrivacyFact(
                        icon: Icons.vpn_key_outlined,
                        title: 'Sensitive preferences',
                        detail: 'Platform secure storage',
                      ),
                      _PrivacyFact(
                        icon: Icons.cloud_off_rounded,
                        title: 'Cloud dependency',
                        detail: 'None for core functionality',
                      ),
                      _PrivacyFact(
                        icon: Icons.visibility_off_outlined,
                        title: 'Telemetry',
                        detail: 'Disabled by default',
                        last: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _PrivacyFact extends StatelessWidget {
  const _PrivacyFact({
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
        if (!last) Divider(height: 1, color: accent.withAlpha(15)),
      ],
    );
  }
}
