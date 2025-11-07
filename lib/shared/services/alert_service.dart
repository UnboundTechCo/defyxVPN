import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:audioplayers/audioplayers.dart';

class AlertService {
  AlertService._internal();
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;

  final Battery _battery = Battery();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _hasVibrator = true;
  int _batteryLevel = 100;
  bool _isDesktop = false;
  bool _soundEnabled = true;

  Future<void> init() async {
    _isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (_isDesktop) {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
    } else {
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
  }

  bool get _canVibrate {
    return !_isDesktop && _hasVibrator && _batteryLevel > 20;
  }

  bool get soundEnabled => _soundEnabled;

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  Future<void> _playSound() async {
    if (!_isDesktop || !_soundEnabled) return;

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/notification.wav'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  Future<void> heartbeat() async {
    if (_isDesktop) {
      await _playSound();
    } else {
      if (!_canVibrate) return;

      try {
        final hasAmplitudeControl = await Vibration.hasAmplitudeControl();
        if (hasAmplitudeControl) {
          await Vibration.vibrate(duration: 35, amplitude: 40);
        } else {
          await Vibration.vibrate(duration: 35);
        }
      } catch (e) {
        debugPrint('Error in heartbeat vibration: $e');
      }
    }
  }

  Future<void> success() async {
    if (_isDesktop) {
      await _playSound();
    } else {
      if (!_canVibrate) return;

      try {
        await Vibration.vibrate(duration: 75);
      } catch (e) {
        debugPrint('Error in success vibration: $e');
      }
    }
  }

  Future<void> error() async {
    if (_isDesktop) {
      await _playSound();
    } else {
      if (!_canVibrate) return;

      try {
        await Vibration.vibrate(duration: 200);
      } catch (e) {
        debugPrint('Error in error vibration: $e');
      }
    }
  }

  Future<void> short() async {
    if (_isDesktop) {
      await _playSound();
    } else {
      if (!_canVibrate) return;

      try {
        await Vibration.vibrate(duration: 50);
      } catch (e) {
        debugPrint('Error in short vibration: $e');
      }
    }
  }

  Future<void> cancel() async {
    if (_isDesktop) {
      try {
        await _audioPlayer.stop();
      } catch (e) {
        debugPrint('Error stopping sound: $e');
      }
    } else {
      try {
        await Vibration.cancel();
      } catch (e) {
        debugPrint('Error canceling vibration: $e');
      }
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
