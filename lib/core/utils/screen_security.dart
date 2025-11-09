import 'dart:io';
import 'package:flutter/material.dart';
import 'package:no_screenshot/no_screenshot.dart';

class ScreenSecurity {
  static final NoScreenshot _noScreenshot = NoScreenshot.instance;

  static Future<void> enableScreenSecurity() async {
    // Screenshot protection is only available on mobile platforms
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('Screen security not available on desktop platforms');
      return;
    }

    try {
      await _noScreenshot.screenshotOff();
    } catch (e) {
      debugPrint('Error enabling screen security: $e');
    }
  }

  static Future<void> disableScreenSecurity() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('Screen security not available on desktop platforms');
      return;
    }

    try {
      await _noScreenshot.screenshotOn();
    } catch (e) {
      debugPrint('Error disabling screen security: $e');
    }
  }

  static Future<void> toggleScreenSecurity() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('Screen security not available on desktop platforms');
      return;
    }

    try {
      await _noScreenshot.toggleScreenshot();
    } catch (e) {
      debugPrint('Error toggling screen security: $e');
    }
  }
}
