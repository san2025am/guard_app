/// أدوات التعامل مع بصمة الإصبع/الوجه لتخزين بيانات الدخول.
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

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

/// خدمة مرافقة لتخزين البيانات على `SecureStorage` والتحقق بالبصمة.
class BiometricAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const MethodChannel _androidCapabilitiesChannel =
      MethodChannel('com.example.security_quard/biometric_capabilities');

  static Set<String>? _androidCapabilitiesCache;

  static const String _kUsernameKey = 'biometric_username';
  static const String _kPasswordKey = 'biometric_password';

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
    if (kIsWeb) {
      return null;
    }

    try {
      final supported = await isDeviceSupported();
      final canCheck = await canCheckBiometrics();
      if (!supported && !canCheck) {
        return null;
      }

      final platform = defaultTargetPlatform;
      final isAndroid = platform == TargetPlatform.android;

      final types = await availableBiometrics();
      final hasFingerprint = types.contains(BiometricType.fingerprint);
      final hasFace = types.contains(BiometricType.face);
      final hasIris = types.contains(BiometricType.iris);
      final hasStrong = types.contains(BiometricType.strong);
      final hasWeak = types.contains(BiometricType.weak);

      if (hasFingerprint) {
        return BiometricMethod.fingerprint;
      }

      if (hasFace) {
        return BiometricMethod.face;
      }
      if (hasIris) {
        return BiometricMethod.iris;
      }

      if (isAndroid) {
        final resolved = await _resolveAndroidMethod(types, hasStrong: hasStrong, hasWeak: hasWeak);
        if (resolved != null) {
          return resolved;
        }
      }

      if (types.isNotEmpty) {
        return BiometricMethod.generic;
      }

      return (supported || canCheck) ? BiometricMethod.generic : null;
    } on PlatformException {
      return null;
    }
  }

  /// يعرض مربع حوار التحقق ويعيد نجاح العملية.
  static Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          
          sensitiveTransaction: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  static Future<BiometricMethod?> _resolveAndroidMethod(
    List<BiometricType> types, {
    required bool hasStrong,
    required bool hasWeak,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    final capabilities = await _androidCapabilities();
    final hasFaceFeature = capabilities.contains('face');
    final hasFingerprintFeature = capabilities.contains('fingerprint');
    final hasIrisFeature = capabilities.contains('iris');

    if (hasFaceFeature && !hasFingerprintFeature) {
      return BiometricMethod.face;
    }
    if (hasFingerprintFeature && !hasFaceFeature) {
      return BiometricMethod.fingerprint;
    }
    if (hasIrisFeature && !hasFaceFeature && !hasFingerprintFeature) {
      return BiometricMethod.iris;
    }

    if (hasFaceFeature && hasWeak && !hasStrong) {
      return BiometricMethod.face;
    }
    if (hasFingerprintFeature && hasStrong && !hasWeak) {
      return BiometricMethod.fingerprint;
    }

    if (hasFaceFeature && hasFingerprintFeature) {
      if (hasWeak && !hasStrong) {
        return BiometricMethod.face;
      }
      if (hasStrong && !hasWeak) {
        return BiometricMethod.fingerprint;
      }
    }

    if (hasWeak && !hasStrong) {
      return hasFaceFeature ? BiometricMethod.face : BiometricMethod.generic;
    }
    if (hasStrong) {
      if (hasFingerprintFeature) {
        return BiometricMethod.fingerprint;
      }
      if (hasFaceFeature) {
        return BiometricMethod.face;
      }
    }

    if (hasIrisFeature) {
      return BiometricMethod.iris;
    }

    return null;
  }

  static Future<Set<String>> _androidCapabilities() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const <String>{};
    }
    final cached = _androidCapabilitiesCache;
    if (cached != null) {
      return cached;
    }
    try {
      final List<dynamic>? raw =
          await _androidCapabilitiesChannel.invokeMethod<List<dynamic>>('detect');
      final capabilities = <String>{
        if (raw != null)
          ...raw
              .whereType<String>()
              .map((value) => value.toLowerCase()),
      };
      _androidCapabilitiesCache = capabilities;
      return capabilities;
    } on MissingPluginException {
      _androidCapabilitiesCache = const <String>{};
      return const <String>{};
    } on PlatformException {
      _androidCapabilitiesCache = const <String>{};
      return const <String>{};
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


  /// يشرح للمستخدم سبب عدم ظهور Face على بعض أجهزة أندرويد (Face Unlock ضعيف).
  static Future<void> explainIfFaceUnavailable(BuildContext context) async {
    try {
      final types = await _auth.getAvailableBiometrics();
      final hasFace   = types.contains(BiometricType.face);
      final hasStrong = types.contains(BiometricType.strong);
      if (hasFace && !hasStrong) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جهازك يدعم فتح الوجه الضعيف فقط، سنستخدم PIN كبديل آمن.')),
        );
      }
    } catch (_) {
      // تجاهل
    }
  }

  /// يحاول المصادقة البيومترية؛ وإن فشلت أو غير مدعومة، يشغّل بديل PIN تلقائياً.
  static Future<bool> authenticateOrPin({
    required String reason,
    required BuildContext context,
    Future<bool> Function(BuildContext)? pinFallback,
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: false,
          sensitiveTransaction: true,
        ),
      );
      if (ok) return true;
      // فشل: فعّل بديل PIN
      if (pinFallback != null) return await pinFallback(context);
      return await _askPinFallback(context);
    } on PlatformException {
      // خطأ (مثل: لا يوجد Face ID في iOS أو قوي في أندرويد)
      if (pinFallback != null) return await pinFallback(context);
      return await _askPinFallback(context);
    }
  }

  /// بديل PIN بسيط؛ غيّره بما يلائمك (مثلاً التحقق عبر خادم).
  static Future<bool> _askPinFallback(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('التحقق برمز PIN'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'أدخل الرمز'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim().length >= 4), child: const Text('تأكيد')),
        ],
      ),
    );
    return ok ?? false;
  }
