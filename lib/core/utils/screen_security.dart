import 'dart:io';
import 'package:flutter/services.dart';

class ScreenSecurity {
  static const MethodChannel _channel =
      MethodChannel('com.defyx.screen_security');

  /// Enable screen security to prevent screenshots and screen recordings
  /// This will hide the ad content from screenshots/recording similar to Telegram
  static Future<void> enableScreenSecurity() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await _channel.invokeMethod('enableScreenSecurity');
      } on PlatformException catch (e) {
        print('Error enabling screen security: ${e.message}');
      }
    }
  }

  /// Disable screen security
  static Future<void> disableScreenSecurity() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await _channel.invokeMethod('disableScreenSecurity');
      } on PlatformException catch (e) {
        print('Error disabling screen security: ${e.message}');
      }
    }
  }
}
