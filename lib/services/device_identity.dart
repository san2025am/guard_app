/// يولّد معرّفًا ثابتًا للجهاز لتتبع تسجيل الدخول والأمان.
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;          // جديد: لاشتقاق معرّف ثابت
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;    // جديد: لاكتشاف الويب

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

  // جديد: مكوّن مشترك للوصول لمعلومات الجهاز
  static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

  /// يسترجع الهوية من التخزين، أو ينشئ واحدة جديدة عند الحاجة.
  static Future<DeviceIdentity> load() async {
    final prefs = await SharedPreferences.getInstance();
    var cachedId = prefs.getString(_cacheIdKey);
    var cachedName = prefs.getString(_cacheNameKey);

    if (cachedId != null && cachedId.isNotEmpty) {
      final fallbackName = await read(); // كان _readDeviceNameFromPlatform
      final name = (cachedName != null && cachedName.isNotEmpty)
          ? cachedName
          : fallbackName;
      if (cachedName == null || cachedName.isEmpty) {
        await prefs.setString(_cacheNameKey, name);
      }
      return DeviceIdentity(id: cachedId, name: name);
    }

    // نحاول أولًا قراءة مُعرّف نظام رسمي/ثابت إن وجد، ثم نشتقّ واحدًا عند الحاجة.
    String generatedId = await _readStableSystemIdOrEmpty();
    String generatedName = await read();

    if (generatedId.isEmpty) {
      // fallback: اشتقاق بصمة ثابتة من خصائص الجهاز + المنصّة
      generatedId = await _deriveStableFingerprintId();
    }

    await prefs.setString(_cacheIdKey, generatedId);
    await prefs.setString(_cacheNameKey, generatedName);

    return DeviceIdentity(id: generatedId, name: generatedName);
  }

  // ========= اسم الجهاز (عام) =========
  /// API رئيسي لقراءة اسم الجهاز بشكل بشري قابل للعرض.
  static Future<String> read() async {
  try {
    if (kIsWeb) return await _readWeb(); // ← إضافة await

    if (Platform.isAndroid)  return _readAndroid();
    if (Platform.isIOS)      return _readIOS();
    if (Platform.isWindows)  return _readWindows();
    if (Platform.isMacOS)    return _readMacOS();
    if (Platform.isLinux)    return _readLinux();
  } catch (_) {}
  return _capitalizeSafe(_platformName());
}

  // ========== Android ==========
 // ========== Android ==========
static Future<String> _readAndroid() async {
  final info = await _plugin.androidInfo;
  final manufacturer = (info.manufacturer ?? info.brand ?? 'Android').trim();
  final model        = (info.model ?? info.device ?? info.product ?? '').trim();

  final prettyModel = model
      .replaceAll(RegExp(r'^\s+|\s+$'), '')
      .replaceAll(RegExp(r'^SM-'), '')                 // سامسونج
      .replaceAllMapped(RegExp(r'^M\d{3}'), (m) => m.group(0)!); // ← هنا التغيير

  final name = _joinNonEmpty([manufacturer, prettyModel]).trim();
  return name.isNotEmpty ? name : 'Android Device';
}

  // ========== iOS ==========
  static Future<String> _readIOS() async {
    final info = await _plugin.iosInfo;
    final machine = info.utsname.machine?.trim(); // مثل iPhone14,5
    final friendly = _iosMachineToModel[machine];
    final userGiven = info.name?.trim();          // اسم يضعه المستخدم للجهاز
    final model = info.model?.trim();             // "iPhone" أو "iPad"

    // الترتيب: تحويل معروف → اسم المستخدم → الموديل → كود machine → "iOS Device"
    final name = _firstNonEmpty([friendly, userGiven, model, machine, 'iOS Device']);
    return name!;
  }

  // ========== Web ==========
// ========== Web ==========
static Future<String> _readWeb() async {
  final info = await _plugin.webBrowserInfo;      // ← await
  final browser = info.browserName.name;          // Chrome / Safari / Firefox / Edge / …
  return '$browser (Web)';
}


  // ========== Windows ==========
  static Future<String> _readWindows() async {
    final w = await _plugin.windowsInfo;
    // الحقول المتاحة عادة: computerName, productName, userName, buildNumber...
    final parts = [
      _safe(w.productName), // مثل "Windows 11 Pro" — إن توفرت
      _safe(w.computerName),
    ];
    final name = _joinNonEmpty(parts);
    return name.isNotEmpty ? name : 'Windows';
  }

  // ========== macOS ==========
  static Future<String> _readMacOS() async {
    final m = await _plugin.macOsInfo;
    // عادة: computerName, model, osRelease...
    final parts = [
      _safe(m.model),         // مثل "MacBookPro18,3" (قد تكون تقنية)
      _safe(m.computerName),  // اسم المستخدم للجهاز
    ];
    final name = _joinNonEmpty(parts);
    return name.isNotEmpty ? name : 'macOS';
  }

  // ========== Linux ==========
  static Future<String> _readLinux() async {
    final l = await _plugin.linuxInfo;
    // الحقول: prettyName, name, version...
    final parts = [
      _safe(l.prettyName),
      _safe(l.name),
      _safe(l.version),
    ];
    final name = _joinNonEmpty(parts);
    return name.isNotEmpty ? name : 'Linux';
  }

  // ========= مُعرّف نظام رسمي إن وُجد =========
  /// محاولة جلب مُعرّف نظام رسمي/ثابت (قد لا يكون متاحًا لكل المنصّات/الإصدارات).
  /// إن لم يتوفر، تُعيد سلسلة فارغة.
  static Future<String> _readStableSystemIdOrEmpty() async {
    try {
      if (kIsWeb) {
        // لا يوجد مُعرّف ثابت للويب بدون خادم؛ سنشتقّ لاحقاً
        return '';
      }
      if (Platform.isAndroid) {
        final a = await _plugin.androidInfo;
        // ملاحظة: device_info_plus لا يوفّر Settings.Secure.ANDROID_ID.
        // نستخدم أقرب ما يمكن أن يبقى ثابتاً نسبياً، ثم سنقوم بهَشّه ضمن fingerprint المشتق.
        // (قد يتغير عبر تحديثات/إعادة ضبط، لذا لا نعتمد عليه وحده)
        final candidate = _joinNonEmpty([a.id, a.hardware, a.fingerprint, a.manufacturer, a.model]).trim();
        return candidate; // قد يكون فارغًا → سنشتق لاحقاً
      }
      if (Platform.isIOS) {
        final i = await _plugin.iosInfo;
        final idfv = (i.identifierForVendor ?? '').trim(); // أفضل خيار على iOS (قد يتغير بعد إعادة تثبيت كل التطبيقات من نفس البائع)
        return idfv;
      }
      if (Platform.isWindows) {
        final w = await _plugin.windowsInfo;
        final candidate = _joinNonEmpty([w.deviceId, w.computerName, w.userName]).trim();
        return candidate;
      }
      if (Platform.isMacOS) {
        final m = await _plugin.macOsInfo;
        final candidate = _joinNonEmpty([m.systemGUID, m.model, m.osRelease]).trim();
        return candidate;
      }
      if (Platform.isLinux) {
        final l = await _plugin.linuxInfo;
        final candidate = _joinNonEmpty([l.machineId, l.prettyName, l.version]).trim();
        return candidate;
      }
    } catch (_) {}
    return '';
    // ملاحظة: لو كانت السلسلة غير موثوقة/قصيرة، سنهشّ خصائص إضافية في fingerprint.
  }

  // ========= اشتقاق مُعرّف ثابت (Fingerprint) =========
  /// يشتقّ مُعرّفًا ثابتًا من خصائص الجهاز المتوفرة + المنصّة، ثم يُمرَّر على SHA-256
  /// ويُضغط Base64Url (بدون =) — مستقر طالما أن الخصائص الأساسية لا تتغير.
  static Future<String> _deriveStableFingerprintId() async {
    try {
      final buf = StringBuffer();

      // اسم المنصّة + إصدار النظام (قدر الإمكان)
      buf.writeln(_platformName());
      try {
     if (kIsWeb) {
        final wb = await _plugin.webBrowserInfo;   // ← await
        buf.writeln(wb.browserName.name);

        } else if (Platform.isAndroid) {
          final a = await _plugin.androidInfo;
          buf
            ..writeln(a.manufacturer)
            ..writeln(a.brand)
            ..writeln(a.model)
            ..writeln(a.device)
            ..writeln(a.product)
            ..writeln(a.hardware)
            ..writeln(a.fingerprint)
            ..writeln(a.id);
        } else if (Platform.isIOS) {
          final i = await _plugin.iosInfo;
          buf
            ..writeln(i.name)
            ..writeln(i.model)
            ..writeln(i.systemName)
            ..writeln(i.systemVersion)
            ..writeln(i.utsname.machine)
            ..writeln(i.identifierForVendor);
        } else if (Platform.isWindows) {
          final w = await _plugin.windowsInfo;
          buf
            ..writeln(w.productName)
            ..writeln(w.computerName)
            ..writeln(w.userName)
            ..writeln(w.deviceId);
        } else if (Platform.isMacOS) {
          final m = await _plugin.macOsInfo;
          buf
            ..writeln(m.computerName)
            ..writeln(m.model)
            ..writeln(m.osRelease)
            ..writeln(m.systemGUID);
        } else if (Platform.isLinux) {
          final l = await _plugin.linuxInfo;
          buf
            ..writeln(l.prettyName)
            ..writeln(l.version)
            ..writeln(l.machineId)
            ..writeln(l.idLike);
        }
      } catch (_) {
        // تجاهل ونكمل بما توفر
      }

      final bytes = utf8.encode(buf.toString());
      final digest = crypto.sha256.convert(bytes);                 // يتطلب crypto
      // نكتفي بـ 16 بايت (128بت) من البداية لسهولة القراءة (كافٍ للاستخدام الداخلي)
      final first16 = digest.bytes.sublist(0, 16);
      return base64Url.encode(first16).replaceAll('=', '');
    } catch (_) {
      // fallback أخير: عشوائي ومخزّن (لن يكون ثابتًا عبر مسح التخزين)
      return _generateFallbackId();
    }
  }

  // ======= Helpers =======
  static String _joinNonEmpty(Iterable<String?> xs) =>
      xs.where((s) => s != null && s!.trim().isNotEmpty).join(' ');

  static String? _firstNonEmpty(Iterable<String?> xs) =>
      xs.firstWhere((s) => s != null && s.trim().isNotEmpty, orElse: () => null);

  static String _safe(Object? x) => (x?.toString() ?? '').trim();

  static String _platformName() {
    if (kIsWeb) return 'Web';
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS)     return 'iOS';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isMacOS)   return 'macOS';
      if (Platform.isLinux)   return 'Linux';
    } catch (_) {}
    return 'Unknown';
  }

  static String _capitalizeSafe(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// ينشئ قيمة عشوائية تُستخدم فقط عند فشل قراءة/اشتقاق المعرف الحقيقي.
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

/// تحويلات شائعة لبعض أكواد iPhone → اسم الجهاز.
/// القاعدة المستقبلية: إن لم تُعرف، نرجع code نفسه أو اسم المستخدم.
const Map<String, String> _iosMachineToModel = {
  // iPhone 13 family
  'iPhone14,5': 'iPhone 13',
  'iPhone14,4': 'iPhone 13 mini',
  'iPhone14,2': 'iPhone 13 Pro',
  'iPhone14,3': 'iPhone 13 Pro Max',
  // iPhone 14 family
  'iPhone15,4': 'iPhone 14',
  'iPhone15,5': 'iPhone 14 Plus',
  'iPhone15,2': 'iPhone 14 Pro',
  'iPhone15,3': 'iPhone 14 Pro Max',
  // iPhone 15 family
  'iPhone16,1': 'iPhone 15',
  'iPhone16,2': 'iPhone 15 Plus',
  'iPhone16,5': 'iPhone 15 Pro',
  'iPhone16,6': 'iPhone 15 Pro Max',
  // أمثلة iPad
  'iPad13,1': 'iPad Air (4th gen)',
  'iPad13,16': 'iPad Air (5th gen)',
  // … أضف عند الحاجة (الدالة تعمل حتى بدون هذه التحويلات).
};

/// مستخرج اسم المتصفح بصورة بسيطة (مستقبلية بما يكفي دون الاعتماد على userAgent الكامل).
class BrowserNameResolver {
  static Future<String> resolve() async {
    try {
      final info = await DeviceInfoPlugin().webBrowserInfo; // ← await
      return info.browserName.name;
    } catch (_) {
      return 'Browser';
    }
  }
}


