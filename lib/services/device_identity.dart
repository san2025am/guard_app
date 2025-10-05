/// يولّد معرّفًا ثابتًا للجهاز لتتبع تسجيل الدخول والأمان.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يحتوي على المعرف والاسم المقروء للجهاز.
class DeviceIdentity {
  const DeviceIdentity({required this.id, required this.name});

  final String id;
  final String name;
}

/// يوفّر أساليب قراءة أو إنشاء الهوية المحلية للجهاز.
class DeviceIdentityService {
  static const _cacheIdKey = 'device_identity_id';
  static const _cacheNameKey = 'device_identity_name';

  /// يسترجع الهوية من التخزين، أو ينشئ واحدة جديدة عند الحاجة.
  static Future<DeviceIdentity> load() async {
    final prefs = await SharedPreferences.getInstance();
    var cachedId = prefs.getString(_cacheIdKey);
    var cachedName = prefs.getString(_cacheNameKey);

    if (cachedId != null && cachedId.isNotEmpty) {
      final fallbackName = await _readDeviceNameFromPlatform();
      final name = (cachedName != null && cachedName.isNotEmpty)
          ? cachedName
          : fallbackName;
      if (cachedName == null || cachedName.isEmpty) {
        await prefs.setString(_cacheNameKey, name);
      }
      return DeviceIdentity(id: cachedId, name: name);
    }

    final deviceInfo = DeviceInfoPlugin();
    String generatedId;
    String generatedName;

    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        generatedId = (info.id ?? info.hardware ?? info.fingerprint ?? '').trim();
        generatedName = '${info.manufacturer ?? 'Android'} ${info.model ?? ''}'.trim();
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        generatedId = (info.identifierForVendor ?? '').trim();
        generatedName = info.name?.trim() ?? info.utsname.machine ?? 'iOS Device';
      } else {
        generatedId = '';
        generatedName = Platform.operatingSystem;
      }
    } catch (_) {
      generatedId = '';
      generatedName = Platform.operatingSystem;
    }

    if (generatedId.isEmpty) {
      generatedId = _generateFallbackId();
    }
    if (generatedName.isEmpty) {
      generatedName = await _readDeviceNameFromPlatform();
    }

    await prefs.setString(_cacheIdKey, generatedId);
    await prefs.setString(_cacheNameKey, generatedName);

    return DeviceIdentity(id: generatedId, name: generatedName);
  }

  /// يحاول قراءة اسم الجهاز من معلومات النظام الأساسية.
  static Future<String> _readDeviceNameFromPlatform() async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        final manufacturer = info.manufacturer ?? 'Android';
        final model = info.model ?? '';
        return '$manufacturer ${model.trim()}'.trim();
      }
      if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        return info.name?.trim() ?? info.utsname.machine ?? 'iOS Device';
      }
    } catch (_) {
      // ignore the error and fall back
    }
    return Platform.operatingSystem;
  }

  /// ينشئ قيمة عشوائية تُستخدم فقط عند فشل قراءة المعرف الحقيقي.
  static String _generateFallbackId() {
    try {
      final random = Random.secure();
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      return base64Url.encode(bytes).replaceAll('=', '');
    } catch (_) {
      final random = Random();
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      return base64Url.encode(bytes).replaceAll('=', '');
    }
  }
}
