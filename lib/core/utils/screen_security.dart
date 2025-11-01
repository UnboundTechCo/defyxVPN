import 'package:flutter/material.dart';
import 'package:no_screenshot/no_screenshot.dart';

class ScreenSecurity {
  static final NoScreenshot _noScreenshot = NoScreenshot.instance;

  /// Enable screen security to prevent screenshots and screen recordings
  /// This will hide the ad content from screenshots/recording similar to Telegram
  static Future<void> enableScreenSecurity() async {
    try {
      await _noScreenshot.screenshotOff();
    } catch (e) {
      debugPrint('Error enabling screen security: $e');
    }
  }

  /// Disable screen security
  static Future<void> disableScreenSecurity() async {
    try {
      await _noScreenshot.screenshotOn();
    } catch (e) {
      debugPrint('Error disabling screen security: $e');
    }
  }

  /// Toggle screen security
  static Future<void> toggleScreenSecurity() async {
    try {
      await _noScreenshot.toggleScreenshot();
    } catch (e) {
      debugPrint('Error toggling screen security: $e');
    }
  }
}