import 'package:flutter/widgets.dart';
import 'package:battery_plus/battery_plus.dart';

class AnimationService {
  AnimationService._internal();
  static final AnimationService _instance = AnimationService._internal();
  factory AnimationService() => _instance;

  final Battery _battery = Battery();
  int _batteryLevel = 100;
  bool _animationsEnabled = true;

  Future<void> init() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _updateAnimationState();

      _battery.onBatteryStateChanged.listen((BatteryState state) async {
        _batteryLevel = await _battery.batteryLevel;
        _updateAnimationState();
      });
    } catch (e) {
      debugPrint('Error initializing animation service: $e');
    }
  }

  void _updateAnimationState() {
    _animationsEnabled = _batteryLevel > 20;
  }

  bool get areAnimationsEnabled => _animationsEnabled;

  Duration adjustDuration(Duration originalDuration) {
    return _animationsEnabled ? originalDuration : Duration.zero;
  }

  bool shouldAnimate() {
    return _animationsEnabled;
  }

  void pauseAnimation(AnimationController controller) {
    if (!_animationsEnabled && controller.isAnimating) {
      controller.stop();
    }
  }

  void resumeAnimation(AnimationController controller) {
    if (_animationsEnabled && !controller.isAnimating) {
      controller.repeat();
    }
  }

  void conditionalRepeat(AnimationController controller, {bool reverse = false}) {
    if (_animationsEnabled) {
      controller.repeat(reverse: reverse);
    } else {
      controller.stop();
    }
  }

  void conditionalForward(AnimationController controller, {double from = 0.0}) {
    if (_animationsEnabled) {
      controller.forward(from: from);
    }
  }
}

