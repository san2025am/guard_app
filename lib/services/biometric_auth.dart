/// أدوات التعامل مع بصمة الإصبع/الوجه لتخزين بيانات الدخول.
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
/// يمثل بيانات الدخول المحفوظة لاسترجاعها بعد التحقق البيومتري.
class StoredCredentials {
  const StoredCredentials({required this.username, required this.password});

  final String username;
  final String password;
}

/// توصيف بسيط لأنواع البصمة المدعومة على الجهاز.
enum BiometricMethod { face, fingerprint, iris, generic }
class BiometricAuthResult {
  final bool biometricVerified;
  final String method; // "face", "fingerprint", "unknown"
  final int attempts;

  BiometricAuthResult({
    required this.biometricVerified,
    required this.method,
    required this.attempts,
  });
}
/// خدمة مرافقة لتخزين البيانات على `SecureStorage` والتحقق بالبصمة.
class BiometricAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _kUsernameKey = 'biometric_username';
  static const String _kPasswordKey = 'biometric_password';

 Future<BiometricAuthResult> authenticateUserWithRetries() async {
    int maxAttempts = 3;
    int attempts = 0;
    bool verified = false;
    String method = "unknown";

    try {
      bool canCheck = await _auth.canCheckBiometrics;
      bool isSupported = await _auth.isDeviceSupported();

      if (!canCheck || !isSupported) {
        return BiometricAuthResult(
            biometricVerified: false, method: "unsupported", attempts: 0);
      }

      List<BiometricType> available = await _auth.getAvailableBiometrics();
      if (available.contains(BiometricType.face)) {
        method = "face";
      } else if (available.contains(BiometricType.fingerprint)) {
        method = "fingerprint";
      }

      while (attempts < maxAttempts && !verified) {
        verified = await _auth.authenticate(
          localizedReason:
              "يرجى التحقق باستخدام ${method == "face" ? "بصمة الوجه" : "بصمة الإصبع"}",
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );

        attempts++;
        if (verified) break;
      }

      return BiometricAuthResult(
        biometricVerified: verified,
        method: method,
        attempts: attempts,
      );
    } catch (e) {
      return BiometricAuthResult(
        biometricVerified: false,
        method: "error",
        attempts: attempts,
      );
    }
  }

  /// يفحص ما إذا كان الجهاز يدعم التحقق البيومتري.
  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// يتحقق من توفر المستشعرات البيومترية على الجهاز.
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// يتأكد من وجود أسلوب بصمة صالح يمكن استخدامه.
  static Future<bool> isBiometricAvailable() async {
    final method = await preferredMethod();
    return method != null;
  }

  /// يرجع قائمة بأنواع التحقق المتاحة (وجه، بصمة، ...).
  static Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return const <BiometricType>[];
    }
  }

  /// يحدد النوع المفضل للاستخدام اعتمادًا على ما يتوافر على الجهاز.
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
<<<<<<< HEAD
    // بعض الأجهزة المدعومة قد لا تُعيد قائمة الأنواع قبل تسجيل بصمة أو في حال الاعتماد على مصادقة النظام.
=======
>>>>>>> 405cf15 (توثيق الجهاز وتفعيل البصمه والتتبع للحارس)
    return BiometricMethod.generic;
  }

  /// يعرض مربع حوار التحقق ويعيد نجاح العملية.
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

  /// يخزن بيانات الدخول مشفرة في `SecureStorage`.
  static Future<void> storeCredentials(String username, String password) async {
    await _storage.write(key: _kUsernameKey, value: username);
    await _storage.write(key: _kPasswordKey, value: password);
  }

  /// يفحص إن كانت بيانات الدخول محفوظة بالفعل.
  static Future<bool> hasStoredCredentials() async {
    final username = await _storage.read(key: _kUsernameKey);
    final password = await _storage.read(key: _kPasswordKey);
    return (username != null && username.isNotEmpty && password != null && password.isNotEmpty);
  }

  /// يسترجع بيانات الدخول المشفرة إن كانت متاحة.
  static Future<StoredCredentials?> readCredentials() async {
    final username = await _storage.read(key: _kUsernameKey);
    final password = await _storage.read(key: _kPasswordKey);
    if (username == null || username.isEmpty || password == null || password.isEmpty) {
      return null;
    }
    return StoredCredentials(username: username, password: password);
  }

  /// يحذف بيانات الدخول المحفوظة.
  static Future<void> clearCredentials() async {
    await _storage.delete(key: _kUsernameKey);
    await _storage.delete(key: _kPasswordKey);
  }
}
