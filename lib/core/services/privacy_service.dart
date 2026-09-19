import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class PrivacyService {
  PrivacyService._();

  static final PrivacyService instance = PrivacyService._();

  static const String _protectExportKey = 'privacy.protect_export';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> deviceAuthenticationSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> protectExportEnabled() async {
    final String? value = await _storage.read(key: _protectExportKey);

    return value == 'true';
  }

  Future<void> setProtectExport(bool enabled) {
    return _storage.write(
      key: _protectExportKey,
      value: enabled ? 'true' : 'false',
    );
  }

  Future<bool> authenticate({required String reason}) async {
    final bool supported = await deviceAuthenticationSupported();

    if (!supported) {
      return false;
    }

    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
    } catch (_) {
      return false;
    }
  }
}
