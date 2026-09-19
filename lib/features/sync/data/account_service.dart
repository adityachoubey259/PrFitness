import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AccountSnapshot {
  const AccountSnapshot({
    required this.id,
    required this.email,
    required this.baseUrl,
  });

  final String id;

  /// Kept for compatibility with the existing sync UI.
  /// It now represents the account login ID, not necessarily an email.
  final String email;

  String get loginId => email;

  final String baseUrl;
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AccountService {
  AccountService({http.Client? client}) : _client = client ?? http.Client();

  static final ValueNotifier<int> sessionEpoch = ValueNotifier<int>(0);

  static const String defaultBaseUrl = String.fromEnvironment(
    'PRFITNESS_API_BASE_URL',
    defaultValue: 'https://prfitness.itltech.in',
  );

  static const String _baseUrlKey = 'sync.base_url';
  static const String _accessKey = 'sync.access_token';
  static const String _refreshKey = 'sync.refresh_token';
  static const String _accountIdKey = 'sync.account_id';
  static const String _emailKey = 'sync.email';
  static const String _deviceIdKey = 'sync.auth_device_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final http.Client _client;

  Future<String?> savedBaseUrl() => _storage.read(key: _baseUrlKey);

  Future<AccountSnapshot?> currentAccount() async {
    final String? id = await _storage.read(key: _accountIdKey);
    final String? loginId = await _storage.read(key: _emailKey);
    final String? baseUrl = await _storage.read(key: _baseUrlKey);
    final String? access = await _storage.read(key: _accessKey);

    if (id == null || loginId == null || baseUrl == null || access == null) {
      return null;
    }

    return AccountSnapshot(id: id, email: loginId, baseUrl: baseUrl);
  }

  Future<AccountSnapshot> register({
    required String baseUrl,
    required String email,
    required String password,
  }) {
    return _authenticate(
      route: '/v1/auth/register',
      baseUrl: baseUrl,
      loginId: email,
      password: password,
    );
  }

  Future<AccountSnapshot> login({
    required String baseUrl,
    required String email,
    required String password,
  }) {
    return _authenticate(
      route: '/v1/auth/login',
      baseUrl: baseUrl,
      loginId: email,
      password: password,
    );
  }

  Future<AccountSnapshot> _authenticate({
    required String route,
    required String baseUrl,
    required String loginId,
    required String password,
  }) async {
    final String normalizedBase = _normalizeBaseUrl(baseUrl);
    final String normalizedLogin = _normalizeLoginId(loginId);

    if (password.length < 10 || password.length > 256) {
      throw const ApiException('Password must contain 10–256 characters.');
    }

    final String deviceId = await _deviceId();

    final http.Response response = await _client
        .post(
          Uri.parse('$normalizedBase$route'),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, Object?>{
            // API field retained for backward compatibility.
            'email': normalizedLogin,
            'password': password,
            'deviceId': deviceId,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final Map<String, dynamic> body = _decodeObject(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_message(body), statusCode: response.statusCode);
    }

    await _storeSession(baseUrl: normalizedBase, body: body);

    final AccountSnapshot? account = await currentAccount();

    if (account == null) {
      throw const ApiException('The secure session could not be stored.');
    }

    return account;
  }

  Future<http.Response> authorizedPost({
    required String path,
    required Object body,
  }) async {
    String? token = await _storage.read(key: _accessKey);

    final String? baseUrl = await _storage.read(key: _baseUrlKey);

    if (token == null || baseUrl == null) {
      throw const ApiException('Sign in before syncing.', statusCode: 401);
    }

    http.Response response = await _postAuthorized(
      baseUrl: baseUrl,
      path: path,
      token: token,
      body: body,
    );

    if (response.statusCode == 401) {
      await refresh();

      token = await _storage.read(key: _accessKey);

      if (token == null) {
        throw const ApiException(
          'Session expired. Sign in again.',
          statusCode: 401,
        );
      }

      response = await _postAuthorized(
        baseUrl: baseUrl,
        path: path,
        token: token,
        body: body,
      );
    }

    return response;
  }

  Future<void> refresh() async {
    final String? baseUrl = await _storage.read(key: _baseUrlKey);
    final String? refreshToken = await _storage.read(key: _refreshKey);

    if (baseUrl == null || refreshToken == null) {
      await clearSession();

      throw const ApiException(
        'Session expired. Sign in again.',
        statusCode: 401,
      );
    }

    final http.Response response = await _client
        .post(
          Uri.parse('$baseUrl/v1/auth/refresh'),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, Object?>{'refreshToken': refreshToken}),
        )
        .timeout(const Duration(seconds: 15));

    final Map<String, dynamic> body = _decodeObject(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      await clearSession();

      throw ApiException(_message(body), statusCode: response.statusCode);
    }

    await _storeSession(baseUrl: baseUrl, body: body);
  }

  Future<void> logout() async {
    final String? baseUrl = await _storage.read(key: _baseUrlKey);
    final String? refreshToken = await _storage.read(key: _refreshKey);

    if (baseUrl != null && refreshToken != null) {
      try {
        await _client
            .post(
              Uri.parse('$baseUrl/v1/auth/logout'),
              headers: const <String, String>{
                'Content-Type': 'application/json',
              },
              body: jsonEncode(<String, Object?>{'refreshToken': refreshToken}),
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // Offline sign-out still removes local credentials.
      }
    }

    await clearSession(preserveBaseUrl: true);
  }

  Future<void> clearSession({bool preserveBaseUrl = true}) async {
    final String? baseUrl = preserveBaseUrl
        ? await _storage.read(key: _baseUrlKey)
        : null;

    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _accountIdKey);
    await _storage.delete(key: _emailKey);

    if (!preserveBaseUrl) {
      await _storage.delete(key: _baseUrlKey);
    } else if (baseUrl != null) {
      await _storage.write(key: _baseUrlKey, value: baseUrl);
    }

    sessionEpoch.value++;
  }

  Future<http.Response> _postAuthorized({
    required String baseUrl,
    required String path,
    required String token,
    required Object body,
  }) {
    return _client
        .post(
          Uri.parse('$baseUrl$path'),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
  }

  Future<void> _storeSession({
    required String baseUrl,
    required Map<String, dynamic> body,
  }) async {
    final String? accessToken = body['accessToken'] as String?;
    final String? refreshToken = body['refreshToken'] as String?;
    final Map<String, dynamic>? account =
        body['account'] as Map<String, dynamic>?;
    final String? id = account?['id'] as String?;
    final String? loginId = account?['email'] as String?;

    if (accessToken == null ||
        refreshToken == null ||
        id == null ||
        loginId == null) {
      throw const ApiException(
        'Server returned an incomplete authentication response.',
      );
    }

    await _storage.write(key: _baseUrlKey, value: baseUrl);
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    await _storage.write(key: _accountIdKey, value: id);
    await _storage.write(key: _emailKey, value: loginId);

    sessionEpoch.value++;
  }

  Future<String> _deviceId() async {
    final String? existing = await _storage.read(key: _deviceIdKey);

    if (existing != null && existing.length >= 24) {
      return existing;
    }

    final Random random = Random.secure();

    final List<int> bytes = List<int>.generate(
      24,
      (_) => random.nextInt(256),
      growable: false,
    );

    final String value = base64Url.encode(bytes).replaceAll('=', '');

    await _storage.write(key: _deviceIdKey, value: value);

    return value;
  }

  String _normalizeLoginId(String source) {
    final String value = source.trim().toLowerCase();

    if (!RegExp(r'^[a-z0-9][a-z0-9@._-]{2,63}$').hasMatch(value)) {
      throw const ApiException(
        'Account ID must be 3–64 characters using letters, numbers, @, dot, dash or underscore.',
      );
    }

    return value;
  }

  String _normalizeBaseUrl(String source) {
    String value = source.trim();

    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }

    final Uri? uri = Uri.tryParse(value);

    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const ApiException('Enter a valid server URL.');
    }

    final String host = uri.host.toLowerCase();

    final bool localDevelopmentHost =
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '10.0.2.2';

    if (uri.scheme == 'http' && !localDevelopmentHost) {
      throw const ApiException('Remote PrFitness servers must use HTTPS.');
    }

    if (uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const ApiException('Enter only the PrFitness server base URL.');
    }

    return value;
  }

  Map<String, dynamic> _decodeObject(String source) {
    if (source.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final dynamic decoded = jsonDecode(source);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // handled below
    }

    return <String, dynamic>{'error': 'Unexpected server response.'};
  }

  String _message(Map<String, dynamic> body) {
    return body['error'] as String? ??
        body['message'] as String? ??
        'Server request failed.';
  }
}
