/// أداة بسيطة للتأكد من سلامة بيئة التشغيل (VPN وتطبيقات تزييف الموقع).
import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

class EnvironmentStatus {
  const EnvironmentStatus({required this.vpnActive, required this.mockLocationDetected});

  final bool vpnActive;
  final bool mockLocationDetected;

  bool get shouldBlock => vpnActive || mockLocationDetected;
}

class EnvironmentSecurity {
  static const MethodChannel _channel =
      MethodChannel('com.example.security_quard/environment_security');

  static Future<EnvironmentStatus> evaluate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const EnvironmentStatus(vpnActive: false, mockLocationDetected: false);
    }

    try {
      final raw = await _channel.invokeMethod<dynamic>('evaluate');
      if (raw is Map) {
        final map = raw.map((key, value) => MapEntry(key.toString(), value));
        final vpn = map['vpnActive'] == true || map['vpn'] == true;
        final mock = map['mockLocationApps'] == true ||
            map['mockLocationSetting'] == true ||
            map['mockLocation'] == true;
        return EnvironmentStatus(vpnActive: vpn, mockLocationDetected: mock);
      }
    } on MissingPluginException {
      // ignore: returning default status when the platform channel is missing
    } on PlatformException {
      // ignore: returning default status on platform failure
    }

    return const EnvironmentStatus(vpnActive: false, mockLocationDetected: false);
  }
}
