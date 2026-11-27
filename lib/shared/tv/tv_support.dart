import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Android TV detection and app-wide focus setup for D-pad navigation.
///
/// Key handling for remotes works on every platform; [isTv] only gates
/// TV-specific polish such as initial (auto) focus and stronger focus colors.
class TvSupport {
  TvSupport._();

  static bool _isTv = false;

  /// Whether the app runs on a TV-style Android device: Android TV / Google
  /// TV, or any Android device without a touchscreen (used with a remote).
  static bool get isTv => _isTv;

  /// Overrides [isTv] in tests.
  @visibleForTesting
  static set debugIsTv(bool value) => _isTv = value;

  /// Detects Android TV. Must run after `WidgetsFlutterBinding.ensureInitialized`.
  ///
  /// On TV, focus highlights are made permanently visible: Flutter otherwise
  /// starts in touch mode on Android and hides them until the first key press,
  /// so a remote user would not see which control is focused at launch.
  static Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final features = info.systemFeatures;
      _isTv =
          features.contains('android.software.leanback') ||
          features.contains('android.hardware.type.television') ||
          // Some TV boxes don't declare the TV features; without a
          // touchscreen the app is driven by a remote either way.
          !features.contains('android.hardware.touchscreen');
    } catch (e) {
      debugPrint('TV detection failed: $e');
    }
    if (_isTv) {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
    }
  }
}
