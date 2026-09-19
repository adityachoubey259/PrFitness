import 'dart:io';

import 'package:flutter/material.dart';

import '../../sync/data/account_service.dart';
import '../data/release_download_service.dart';

class SecureLoginScreen extends StatefulWidget {
  const SecureLoginScreen({
    super.key,
    required this.accountService,
    required this.onAuthenticated,
  });

  final AccountService accountService;
  final ValueChanged<AccountSnapshot> onAuthenticated;

  @override
  State<SecureLoginScreen> createState() => _SecureLoginScreenState();
}

class _SecureLoginScreenState extends State<SecureLoginScreen> {
  final TextEditingController _server = TextEditingController();
  final TextEditingController _loginId = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _registerMode = false;
  bool _working = false;
  bool _obscure = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _server.dispose();
    _loginId.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final String? base = await widget.accountService.savedBaseUrl();

    final AccountSnapshot? current = await widget.accountService
        .currentAccount();

    if (!mounted) {
      return;
    }

    _server.text = current?.baseUrl ?? base ?? AccountService.defaultBaseUrl;

    _loginId.text = current?.loginId ?? '';

    setState(() {
      _loading = false;
    });

    if (current != null) {
      widget.onAuthenticated(current);
    }
  }

  Future<void> _submit() async {
    if (_working) {
      return;
    }

    setState(() {
      _working = true;
    });

    try {
      final AccountSnapshot account = _registerMode
          ? await widget.accountService.register(
              baseUrl: _server.text,
              email: _loginId.text,
              password: _password.text,
            )
          : await widget.accountService.login(
              baseUrl: _server.text,
              email: _loginId.text,
              password: _password.text,
            );

      if (!mounted) {
        return;
      }

      _password.clear();

      widget.onAuthenticated(account);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication unavailable. $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _saveRelease(ReleaseArtifact artifact) async {
    try {
      final String path = await ReleaseDownloadService.saveArtifact(artifact);

      if (!mounted || path.isEmpty) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Saved to $path')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _settings() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Login settings',
                style: Theme.of(sheetContext).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _server,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'PrFitness API URL',
                  prefixIcon: Icon(Icons.dns_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Passwords are never stored in PrFitness. '
                'Only session tokens are kept in platform secure storage. '
                'The API allows at most two active devices per account.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: Platform.isWindows
                      ? () {
                          Navigator.of(sheetContext).pop();

                          _saveRelease(ReleaseArtifact.apk);
                        }
                      : null,
                  icon: const Icon(Icons.android_rounded),
                  label: const Text('Download PrFitness APK'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: Platform.isWindows
                      ? () {
                          Navigator.of(sheetContext).pop();

                          _saveRelease(ReleaseArtifact.aab);
                        }
                      : null,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Download Android App Bundle'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              colors.surface,
              colors.primaryContainer.withValues(alpha: 0.46),
              colors.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.bolt_rounded,
                                color: colors.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'PrFitness',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text('Secure account access'),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Login settings',
                              onPressed: _settings,
                              icon: const Icon(Icons.settings_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        SegmentedButton<bool>(
                          segments: const <ButtonSegment<bool>>[
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('Sign in'),
                              icon: Icon(Icons.login_rounded),
                            ),
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('Create account'),
                              icon: Icon(Icons.person_add_alt_1_rounded),
                            ),
                          ],
                          selected: <bool>{_registerMode},
                          onSelectionChanged: (Set<bool> value) {
                            setState(() {
                              _registerMode = value.first;
                            });
                          },
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          controller: _loginId,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Account ID',
                            hintText: 'e.g. sanjay or sanjay@example.com',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          enableSuggestions: false,
                          autocorrect: false,
                          onSubmitted: (_) {
                            _submit();
                          },
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscure = !_obscure;
                                });
                              },
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _working ? null : _submit,
                            icon: _working
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _registerMode
                                        ? Icons.person_add_rounded
                                        : Icons.login_rounded,
                                  ),
                            label: Text(
                              _registerMode
                                  ? 'Create secure account'
                                  : 'Sign in securely',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Maximum 2 active devices per account. '
                          'A third device is rejected until one active session signs out.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
