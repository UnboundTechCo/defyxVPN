import 'package:flutter/services.dart';

class TvKeyboardHelper {
  static bool isActivationKey(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA) {
      return true;
    }
    if (event is KeyDownEvent) {
      return event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA;
    }
    return false;
  }

  static bool isBackKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack;
  }

  static bool isNavigationKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight;
  }
}
