import 'dart:async';

import 'package:flutter/material.dart';

import '../core/database/app_database.dart';
import '../core/theme/pr_theme.dart';
import '../features/auth/presentation/secure_login_screen.dart';
import '../features/sync/data/account_service.dart';
import 'prfitness_app.dart';

class PrFitnessLauncher extends StatefulWidget {
  const PrFitnessLauncher({super.key});

  @override
  State<PrFitnessLauncher> createState() => _PrFitnessLauncherState();
}

class _PrFitnessLauncherState extends State<PrFitnessLauncher> {
  final AccountService _accounts = AccountService();

  AccountSnapshot? _account;
  AppDatabase? _database;

  @override
  void initState() {
    super.initState();

    AccountService.sessionEpoch.addListener(_sessionChanged);
  }

  void _openAccount(AccountSnapshot account) {
    if (_account?.id == account.id && _database != null) {
      return;
    }

    final String safeId = account.id
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toLowerCase();

    configurePrFitnessDatabaseName('prfitness_user_$safeId');

    final AppDatabase database = AppDatabase();

    final AppDatabase? previous = _database;

    setState(() {
      _account = account;
      _database = database;
    });

    if (previous != null) {
      unawaited(previous.close());
    }
  }

  Future<void> _sessionChanged() async {
    final AccountSnapshot? account = await _accounts.currentAccount();

    if (!mounted) {
      return;
    }

    if (account == null) {
      final AppDatabase? database = _database;

      setState(() {
        _account = null;
        _database = null;
      });

      await database?.close();
      return;
    }

    _openAccount(account);
  }

  Future<void> _logout() async {
    await _accounts.logout();
  }

  @override
  void dispose() {
    AccountService.sessionEpoch.removeListener(_sessionChanged);

    final AppDatabase? database = _database;

    if (database != null) {
      unawaited(database.close());
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AccountSnapshot? account = _account;
    final AppDatabase? database = _database;

    if (account == null || database == null) {
      return MaterialApp(
        title: 'PrFitness',
        debugShowCheckedModeBanner: false,
        theme: PrTheme.pinkWhite(),
        darkTheme: PrTheme.blackGold(),
        home: SecureLoginScreen(
          accountService: _accounts,
          onAuthenticated: _openAccount,
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: PrFitnessApp(database: database)),
          Positioned(
            right: 14,
            bottom: 14,
            child: Material(
              color: Colors.black87,
              elevation: 8,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  unawaited(_logout());
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        account.loginId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
