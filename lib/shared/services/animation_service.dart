import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

class AnimationService {
  AnimationService._internal();
  static final AnimationService _instance = AnimationService._internal();
  factory AnimationService() => _instance;

  final Battery _battery = Battery();
  int _batteryLevel = 100;
  static const int _lowBatteryThreshold = 20;

  Future<void> init() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _battery.onBatteryStateChanged.listen((BatteryState state) async {
        _batteryLevel = await _battery.batteryLevel;
      });
    } catch (e) {
      debugPrint('Error initializing animation service: $e');
    }
  }

  bool shouldAnimate() {
    return _batteryLevel > _lowBatteryThreshold;
  }

  Duration adjustDuration(Duration originalDuration) {
    return shouldAnimate() ? originalDuration : Duration.zero;
  }

  void conditionalRepeat(AnimationController controller, {bool reverse = false}) {
    if (shouldAnimate()) {
      controller.repeat(reverse: reverse);
    } else {
      controller.stop();
    }
  }

  void conditionalForward(AnimationController controller, {double? from}) {
    if (shouldAnimate()) {
      controller.forward(from: from);
    } else {
      controller.stop();
    }
  }
}

