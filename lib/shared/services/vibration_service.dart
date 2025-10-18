import 'package:flutter/widgets.dart';
import 'package:vibration/vibration.dart';

class VibrationService {
  VibrationService._internal();
  static final VibrationService _instance = VibrationService._internal();
  factory VibrationService() => _instance;

  bool _hasVibrator = true;

  Future<void> init() async {
    try {
      _hasVibrator = await Vibration.hasVibrator() ?? false;
    } catch (e) {
      debugPrint('Error checking vibrator: $e');
      _hasVibrator = false;
    }
  }

  Future<void> vibrateHeartbeat() async {
    if (!_hasVibrator) return;
    
    try {
      await Vibration.vibrate(duration: 50);
      await Future.delayed(const Duration(milliseconds: 100));
      await Vibration.vibrate(duration: 50);
    } catch (e) {
      debugPrint('Error in heartbeat vibration: $e');
    }
  }

  Future<void> vibrateSuccess() async {
    if (!_hasVibrator) return;
    
    try {
      await Vibration.vibrate(duration: 500);
    } catch (e) {
      debugPrint('Error in success vibration: $e');
    }
  }

  Future<void> vibrateError() async {
    if (!_hasVibrator) return;
    
    try {
      await Vibration.vibrate(duration: 200);
    } catch (e) {
      debugPrint('Error in error vibration: $e');
    }
  }

  Future<void> vibrateShort() async {
    if (!_hasVibrator) return;
    
    try {
      await Vibration.vibrate(duration: 100);
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

