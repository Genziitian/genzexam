import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Manages dynamic home-screen app icon switching between standard and Pro branding.
class AppIconService {
  static const MethodChannel _channel = MethodChannel('in.genziitian.quizlab/app_icon');

  /// Synchronizes launcher app icon with the user's Pro status.
  static Future<void> syncIcon({required bool isPro}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final current = await _channel.invokeMethod<String>('getCurrentIcon');
      final target = isPro ? 'pro' : 'default';
      if (current != target) {
        await _channel.invokeMethod<bool>('setIcon', {'icon': target});
      }
    } catch (_) {
      // Graceful fallback for test runs and devices without custom launcher support.
    }
  }
}
