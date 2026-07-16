import 'package:flutter/foundation.dart';

class PlatformUtils {
  PlatformUtils._();

  static bool get isWeb => kIsWeb;

  static bool get isMobile {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static bool get isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static bool isLargeFormFactor(double width) {
    if (isDesktop) return true;
    if (isWeb && width >= 900) return true;
    return false;
  }
}
