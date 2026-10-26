import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kazumi/services/platform/platform_environment_service.dart';

Future<void> initializeDeviceCapabilities() =>
    PlatformEnvironmentService.initializeAndroidDeviceProfile();

bool isAndroidTV() =>
    Platform.isAndroid &&
    PlatformEnvironmentService.androidDeviceProfile.isTelevision;

bool isConstrainedAndroidDevice() {
  if (!Platform.isAndroid) {
    return false;
  }
  final profile = PlatformEnvironmentService.androidDeviceProfile;
  return profile.isTelevision ||
      profile.isLowRamDevice ||
      !profile.is64Bit ||
      (profile.memoryClassMb > 0 && profile.memoryClassMb <= 256);
}

bool prefersReducedEffects() => isConstrainedAndroidDevice();

Future<bool> isLowResolution() async {
  if (Platform.isMacOS) {
    return false;
  }
  final screenInfo = await getScreenInfo();
  return screenInfo['height']! / screenInfo['ratio']! < 900;
}

Future<Map<String, double>> getScreenInfo() async {
  final mediaQuery = MediaQueryData.fromView(
    WidgetsBinding.instance.platformDispatcher.views.first,
  );
  final screenSize =
      WidgetsBinding.instance.platformDispatcher.displays.first.size;
  return {
    'width': screenSize.width,
    'height': screenSize.height,
    'ratio': mediaQuery.devicePixelRatio,
  };
}

bool isDesktop() {
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}
