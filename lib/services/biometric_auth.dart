import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class StoredCredentials {
  const StoredCredentials({required this.username, required this.password});

  final String username;
  final String password;
}

enum BiometricMethod { face, fingerprint, iris, generic }

class BiometricAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _kUsernameKey = 'biometric_username';
  static const String _kPasswordKey = 'biometric_password';

  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> isBiometricAvailable() async {
    final method = await preferredMethod();
    return method != null;
  }

  static Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return const <BiometricType>[];
    }
  }

  static Future<BiometricMethod?> preferredMethod() async {
    if (!await isDeviceSupported()) {
      return null;
    }

    final types = await availableBiometrics();
    if (types.contains(BiometricType.face)) {
      return BiometricMethod.face;
    }
    if (types.contains(BiometricType.fingerprint)) {
      return BiometricMethod.fingerprint;
    }
    if (types.contains(BiometricType.iris)) {
      return BiometricMethod.iris;
    }
    if (types.contains(BiometricType.strong) || types.contains(BiometricType.weak)) {
      return BiometricMethod.generic;
    }
    if (types.isNotEmpty) {
      return BiometricMethod.generic;
    }
    // بعض الأجهزة المدعومة قد لا تُعيد قائمة الأنواع قبل تسجيل بصمة أو في حال الاعتماد على مصادقة النظام.
    return BiometricMethod.generic;
  }

  static Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  static Future<void> storeCredentials(String username, String password) async {
    await _storage.write(key: _kUsernameKey, value: username);
    await _storage.write(key: _kPasswordKey, value: password);
  }

  static Future<bool> hasStoredCredentials() async {
    final username = await _storage.read(key: _kUsernameKey);
    final password = await _storage.read(key: _kPasswordKey);
    return (username != null && username.isNotEmpty && password != null && password.isNotEmpty);
  }

  static Future<StoredCredentials?> readCredentials() async {
    final username = await _storage.read(key: _kUsernameKey);
    final password = await _storage.read(key: _kPasswordKey);
    if (username == null || username.isEmpty || password == null || password.isEmpty) {
      return null;
    }
    return StoredCredentials(username: username, password: password);
  }

  static Future<void> clearCredentials() async {
    await _storage.delete(key: _kUsernameKey);
    await _storage.delete(key: _kPasswordKey);
  }
}
