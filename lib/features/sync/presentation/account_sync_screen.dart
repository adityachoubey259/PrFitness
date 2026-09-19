import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/pr_theme.dart';
import '../../../core/widgets/premium_panel.dart';
import '../data/account_service.dart';
import '../data/sync_database.dart';
import '../data/sync_service.dart';

class AccountSyncScreen extends StatefulWidget {
  const AccountSyncScreen({required this.database, super.key});

  final AppDatabase database;

  @override
  State<AccountSyncScreen> createState() => _AccountSyncScreenState();
}

class _AccountSyncScreenState extends State<AccountSyncScreen> {
  final AccountService _accounts = AccountService();
  late final SyncService _sync = SyncService(
    widget.database,
    accountService: _accounts,
  );

  final TextEditingController _server = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  AccountSnapshot? _account;
  bool _loading = true;
  bool _working = false;
  String? _message;
  String? _lastSync;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _server.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await widget.database.ensureSyncInfrastructure();
    final AccountSnapshot? account = await _accounts.currentAccount();
    final String? server = await _accounts.savedBaseUrl();
    final String? last = await widget.database.readSetting(
      'sync.last_success_utc',
    );

    if (!mounted) return;
    setState(() {
      _account = account;
      _server.text = account?.baseUrl ?? server ?? '';
      _email.text = account?.email ?? '';
      _lastSync = last;
      _loading = false;
    });
  }

  Future<void> _authenticate({required bool register}) async {
    if (_working) return;
    setState(() {
      _working = true;
      _message = null;
    });

    try {
      final AccountSnapshot result = register
          ? await _accounts.register(
              baseUrl: _server.text,
              email: _email.text,
              password: _password.text,
            )
          : await _accounts.login(
              baseUrl: _server.text,
              email: _email.text,
              password: _password.text,
            );

      if (!mounted) return;
      setState(() {
        _account = result;
        _password.clear();
        _message = register ? 'Secure account created.' : 'Signed in securely.';
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = 'Connection failed. Local data remains safe. $error',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _syncNow() async {
    if (_working) return;
    setState(() {
      _working = true;
      _message = null;
    });

    try {
      final SyncResult result = await _sync.syncNow();
      final String? last = await widget.database.readSetting(
        'sync.last_success_utc',
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _lastSync = last;
        _message =
            'Sync complete • ${result.pushed} pushed • ${result.pulled} pulled'
            '${result.conflicts == 0 ? '' : ' • ${result.conflicts} conflict(s)'}';
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error) {
      if (mounted) {
        setState(
          () => _message =
              'Sync unavailable. PrFitness remains fully offline-capable. $error',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _logout() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _accounts.logout();
      if (!mounted) return;
      setState(() {
        _account = null;
        _password.clear();
        _message = 'Signed out. Local data remains on this device.';
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final Color accent = PrTheme.accent(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Account & Sync'),
      ),
      body: StreamBuilder<List<SyncOutboxRow>>(
        stream: widget.database.watchSyncOutboxRows(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<SyncOutboxRow>> outboxSnapshot,
            ) {
              final List<SyncOutboxRow> outbox =
                  outboxSnapshot.data ?? <SyncOutboxRow>[];

              return StreamBuilder<List<SyncConflictRow>>(
                stream: widget.database.watchOpenSyncConflicts(),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<SyncConflictRow>> conflictSnapshot,
                    ) {
                      final List<SyncConflictRow> conflicts =
                          conflictSnapshot.data ?? <SyncConflictRow>[];

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                        children: <Widget>[
                          PremiumPanel(
                            borderRadius: 34,
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 62,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: <Color>[
                                        accent,
                                        PrTheme.secondaryAccent(context),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(21),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: accent.withAlpha(60),
                                        blurRadius: 24,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.cloud_sync_rounded,
                                    color: PrTheme.isBlackGold(context)
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        _account == null
                                            ? 'Offline first. Cloud optional.'
                                            : 'Protected cloud sync',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        _account?.email ?? 'No PostgreSQL credentials ever enter the app.',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (_account == null)
                            _AuthPanel(
                              server: _server,
                              email: _email,
                              password: _password,
                              working: _working,
                              onRegister: () => _authenticate(register: true),
                              onLogin: () => _authenticate(register: false),
                            )
                          else
                            _SyncPanel(
                              account: _account!,
                              pending: outbox.length,
                              conflicts: conflicts.length,
                              lastSync: _lastSync,
                              working: _working,
                              onSync: _syncNow,
                              onLogout: _logout,
                            ),
                          if (conflicts.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 22),
                            Text(
                              'Conflict review',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),
                            for (final SyncConflictRow conflict in conflicts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ConflictCard(
                                  conflict: conflict,
                                  onRemote: () async {
                                    await _sync.useRemote(conflict);
                                    if (mounted) {
                                      setState(
                                        () => _message =
                                            'Server version applied.',
                                      );
                                    }
                                  },
                                  onLocal: () async {
                                    await _sync.keepLocal(conflict);
                                    if (mounted) {
                                      setState(
                                        () => _message = 'Local version queued for the next sync.',
                                      );
                                    }
                                  },
                                ),
                              ),
                          ],
                          if (_message != null) ...<Widget>[
                            const SizedBox(height: 16),
                            PremiumPanel(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(_message!)),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          const PremiumPanel(
                            child: Column(
                              children: <Widget>[
                                _Fact(
                                  icon: Icons.storage_rounded,
                                  title: 'Immediate source of truth',
                                  detail: 'Local SQLite',
                                ),
                                _Fact(
                                  icon: Icons.outbox_rounded,
                                  title: 'Offline mutations',
                                  detail: 'Automatic persistent outbox',
                                ),
                                _Fact(
                                  icon: Icons.lock_outline_rounded,
                                  title: 'Credentials',
                                  detail: 'Platform secure storage',
                                ),
                                _Fact(
                                  icon: Icons.dns_rounded,
                                  title: 'Cloud boundary',
                                  detail: 'HTTPS → Go API → PostgreSQL',
                                  last: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
              );
            },
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({
    required this.server,
    required this.email,
    required this.password,
    required this.working,
    required this.onRegister,
    required this.onLogin,
  });

  final TextEditingController server;
  final TextEditingController email;
  final TextEditingController password;
  final bool working;
  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      borderRadius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Private sync endpoint',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use HTTPS in production. Android emulator development can use http://10.0.2.2:8080.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: server,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Password',
              helperText: 'Minimum 10 characters',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: working ? null : onRegister,
                  child: const Text('Create account'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: working ? null : onLogin,
                  child: Text(working ? 'Working...' : 'Sign in'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SyncPanel extends StatelessWidget {
  const _SyncPanel({
    required this.account,
    required this.pending,
    required this.conflicts,
    required this.lastSync,
    required this.working,
    required this.onSync,
    required this.onLogout,
  });

  final AccountSnapshot account;
  final int pending;
  final int conflicts;
  final String? lastSync;
  final bool working;
  final VoidCallback onSync;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    DateTime? parsed;
    if (lastSync != null) parsed = DateTime.tryParse(lastSync!)?.toLocal();

    final String last = parsed == null
        ? 'Never'
        : '${parsed.day.toString().padLeft(2, '0')}/'
              '${parsed.month.toString().padLeft(2, '0')} '
              '${parsed.hour.toString().padLeft(2, '0')}:'
              '${parsed.minute.toString().padLeft(2, '0')}';

    return PremiumPanel(
      borderRadius: 30,
      child: Column(
        children: <Widget>[
          _Status(label: 'Server', value: account.baseUrl),
          _Status(label: 'Pending', value: '$pending'),
          _Status(label: 'Conflicts', value: '$conflicts'),
          _Status(label: 'Last sync', value: last, last: true),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: FilledButton.icon(
              onPressed: working ? null : onSync,
              icon: working
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(working ? 'Synchronizing...' : 'Sync now'),
            ),
          ),
          const SizedBox(height: 7),
          TextButton(
            onPressed: working ? null : onLogout,
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 90,
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (!last) const Divider(height: 1),
      ],
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.onRemote,
    required this.onLocal,
  });

  final SyncConflictRow conflict;
  final VoidCallback onRemote;
  final VoidCallback onLocal;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);
    return PremiumPanel(
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.compare_arrows_rounded, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${conflict.entityType} • ${conflict.entityId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Both the device and server changed this record after their last shared version.',
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onRemote,
                  child: const Text('Use server'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton(
                  onPressed: onLocal,
                  child: const Text('Keep local'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
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
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: <Widget>[
              Icon(icon, color: accent),
              const SizedBox(width: 11),
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
