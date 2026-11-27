import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Classifies remote-control, gamepad and keyboard keys for D-pad handling.
class TvKeyboardHelper {
  TvKeyboardHelper._();

  /// Keys that "press" the focused control. On Android TV the D-pad center
  /// button (KEYCODE_DPAD_CENTER) arrives as [LogicalKeyboardKey.select].
  static final Set<LogicalKeyboardKey> activationKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.gameButtonA,
  };

  static bool isActivationKey(KeyEvent event) =>
      activationKeys.contains(event.logicalKey);

  static bool isBackKey(KeyEvent event) =>
      event.logicalKey == LogicalKeyboardKey.goBack ||
      event.logicalKey == LogicalKeyboardKey.escape;

  static bool isNavigationKey(KeyEvent event) => directionOf(event) != null;

  /// The traversal direction of an arrow / D-pad key, or null for other keys.
  static TraversalDirection? directionOf(KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) return TraversalDirection.up;
    if (key == LogicalKeyboardKey.arrowDown) return TraversalDirection.down;
    if (key == LogicalKeyboardKey.arrowLeft) return TraversalDirection.left;
    if (key == LogicalKeyboardKey.arrowRight) return TraversalDirection.right;
    return null;
  }
}
