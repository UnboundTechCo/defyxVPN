import 'package:flutter/widgets.dart';
import 'package:vibration/vibration.dart';
import 'package:battery_plus/battery_plus.dart';

class VibrationService {
  VibrationService._internal();
  static final VibrationService _instance = VibrationService._internal();
  factory VibrationService() => _instance;

  final Battery _battery = Battery();
  bool _hasVibrator = true;
  int _batteryLevel = 100;

  Future<void> init() async {
    try {
      _hasVibrator = await Vibration.hasVibrator();
      _batteryLevel = await _battery.batteryLevel;

      _battery.onBatteryStateChanged.listen((BatteryState state) async {
        _batteryLevel = await _battery.batteryLevel;
      });
    } catch (e) {
      debugPrint('Error checking vibrator: $e');
      _hasVibrator = false;
    }
  }

  bool get _canVibrate {
    return _hasVibrator && _batteryLevel > 20;
  }

  Future<void> vibrateHeartbeat() async {
    if (!_canVibrate) return;

    try {
      final hasAmplitudeControl =
          await Vibration.hasAmplitudeControl() ?? false;
      if (hasAmplitudeControl) {
        await Vibration.vibrate(duration: 35, amplitude: 40);
      } else {
        await Vibration.vibrate(duration: 35);
      }
    } catch (e) {
      debugPrint('Error in heartbeat vibration: $e');
    }
  }

  Future<void> vibrateSuccess() async {
    if (!_canVibrate) return;

    try {
      await Vibration.vibrate(duration: 75);
    } catch (e) {
      debugPrint('Error in success vibration: $e');
    }
  }

  Future<void> vibrateError() async {
    if (!_canVibrate) return;

    try {
      await Vibration.vibrate(duration: 200);
    } catch (e) {
      debugPrint('Error in error vibration: $e');
    }
  }

  Future<void> vibrateShort() async {
    if (!_canVibrate) return;

    try {
      await Vibration.vibrate(duration: 50);
    } catch (e) {
      debugPrint('Error in short vibration: $e');
    }
  }

  Future<void> cancel() async {
    try {
      await Vibration.cancel();
    } catch (e) {
      debugPrint('Error canceling vibration: $e');
    }
  }
}
