import 'dart:io';

import 'package:flutter/services.dart';
import 'package:kazumi/services/logging/logger.dart';

class AndroidDeviceProfile {
  const AndroidDeviceProfile({
    required this.isTelevision,
    required this.isLowRamDevice,
    required this.memoryClassMb,
    required this.is64Bit,
  });

  const AndroidDeviceProfile.fallback()
      : isTelevision = false,
        isLowRamDevice = false,
        memoryClassMb = 0,
        is64Bit = true;

  final bool isTelevision;
  final bool isLowRamDevice;
  final int memoryClassMb;
  final bool is64Bit;

  factory AndroidDeviceProfile.fromMap(Map<Object?, Object?> map) {
    return AndroidDeviceProfile(
      isTelevision: map['isTelevision'] == true,
      isLowRamDevice: map['isLowRamDevice'] == true,
      memoryClassMb: (map['memoryClassMb'] as num?)?.toInt() ?? 0,
      is64Bit: map['is64Bit'] != false,
    );
  }
}

class PlatformEnvironmentService {
  PlatformEnvironmentService._();

  static const _intentChannel = MethodChannel('com.predidit.kazumi/intent');
  static AndroidDeviceProfile _androidDeviceProfile =
      const AndroidDeviceProfile.fallback();

  static AndroidDeviceProfile get androidDeviceProfile => _androidDeviceProfile;

  static Future<void> initializeAndroidDeviceProfile() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      final result = await _intentChannel.invokeMethod<Map<Object?, Object?>>(
        'getAndroidDeviceProfile',
      );
      if (result != null) {
        _androidDeviceProfile = AndroidDeviceProfile.fromMap(result);
      }
    } on PlatformException catch (e) {
      KazumiLogger().w(
        "Failed to get Android device profile: '${e.message}'.",
      );
    }
  }

  static Future<bool> isInMultiWindowMode() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      return await _intentChannel.invokeMethod('checkIfInMultiWindowMode');
    } on PlatformException catch (e) {
      KazumiLogger().e("Failed to check multi window mode: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> isRunningOnX11() async {
    if (!Platform.isLinux) {
      return false;
    }
    try {
      return await _intentChannel.invokeMethod('isRunningOnX11');
    } on PlatformException catch (e) {
      KazumiLogger().e("Failed to check X11 environment: '${e.message}'.");
      return false;
    }
  }

  static Future<int> getAndroidSdkVersion() async {
    if (!Platform.isAndroid) {
      return 0;
    }
    try {
      return await _intentChannel.invokeMethod('getAndroidSdkVersion');
    } on PlatformException catch (e) {
      KazumiLogger().e("Failed to get Android SDK version: '${e.message}'.");
      return 0;
    }
  }
}
