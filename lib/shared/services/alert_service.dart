import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:vibration/vibration.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:audioplayers/audioplayers.dart';

abstract class AlertSub {
  bool _hasAction = false;
  bool get hasAction => _hasAction;
  Future<void> init();
  Future<void> success();
  Future<void> heartbeat();
  Future<void> error();
  Future<void> short();
  Future<void> cancel();
  void setActionEnabled(bool enabled);
}

final class VibrationService extends AlertSub {
  @override
  Future<void> init() async {
    _hasAction = await Vibration.hasVibrator();
  }

  @override
  void setActionEnabled(bool enabled) {
    _hasAction = enabled;
  }

  @override
  Future<void> success() async {
    try {
      await Vibration.vibrate(duration: 75);
    } catch (e) {
      debugPrint('Error in success vibration: $e');
    }
  }

  @override
  Future<void> heartbeat() async {
    try {
      await Vibration.vibrate(duration: 35);
    } catch (e) {
      debugPrint('Error in heartbeat vibration: $e');
    }
  }

  @override
  Future<void> error() async {
    try {
      await Vibration.vibrate(duration: 100);
    } catch (e) {
      debugPrint('Error in error vibration: $e');
    }
  }

  @override
  Future<void> short() async {
    try {
      await Vibration.vibrate(duration: 50);
    } catch (e) {
      debugPrint('Error in short vibration: $e');
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await Vibration.cancel();
    } catch (e) {
      debugPrint('Error canceling vibration: $e');
    }
  }
}

final class AudioService extends AlertSub {
  static bool _soundEnabledState = true;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  Future<void> init() async {
    _hasAction = _soundEnabledState;

    try {
      await _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
    }
  }

  @override
  void setActionEnabled(bool enabled) {
    _hasAction = enabled;
    _soundEnabledState = enabled;
  }

  Future<void> _playSound() async {
    if (!hasAction) return;

    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        unawaited(_audioPlayer.stop().then((_) {
          return _audioPlayer.play(AssetSource('sounds/notification.wav'));
        }).catchError((e) {
          debugPrint('Error playing sound on desktop: $e');
        }));
      } else {
        if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
          await _audioPlayer.stop();
          await _audioPlayer.play(AssetSource('sounds/notification.wav'));
        } else {
          SchedulerBinding.instance.addPostFrameCallback((_) async {
            try {
              await _audioPlayer.stop();
              await _audioPlayer.play(AssetSource('sounds/notification.wav'));
            } catch (e) {
              debugPrint('Error playing sound in post frame callback: $e');
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  @override
  Future<void> success() async {
    try {
      await _playSound();
    } catch (e) {
      debugPrint('Error in success audio: $e');
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping sound: $e');
    }
  }

  @override
  Future<void> short() async {
    try {
      await _playSound();
    } catch (e) {
      debugPrint('Error in short audio: $e');
    }
  }

  @override
  Future<void> error() async {
    try {
      await _playSound();
    } catch (e) {
      debugPrint('Error in error audio: $e');
    }
  }

  @override
  Future<void> heartbeat() async {
    try {
      await _playSound();
    } catch (e) {
      debugPrint('Error in heartbeat audio: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.dispose();
    } catch (e) {
      debugPrint('Error disposing audio player: $e');
    }
  }
}

class AlertService {
  AlertService._internal();
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;

  AlertSub? _alertSub;
  final Battery _battery = Battery();
  int _batteryLevel = 100;

  bool get _canAlert => _batteryLevel > 20;

  Future<void> init() async {
    if (kIsWeb || (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      _alertSub = AudioService();
    } else if (Platform.isIOS || Platform.isAndroid) {
      _alertSub = VibrationService();
    }

    await _alertSub?.init();

    _battery.onBatteryStateChanged.listen((BatteryState state) async {
      _batteryLevel = await _battery.batteryLevel;
    });
  }

  void _runAlert(void Function()? fn) {
    if (_canAlert && _alertSub?.hasAction == true) fn?.call();
  }

  void success() => _runAlert(_alertSub?.success);
  void heartbeat() => _runAlert(_alertSub?.heartbeat);
  void error() => _runAlert(_alertSub?.error);
  void short() => _runAlert(_alertSub?.short);
  void cancel() => _runAlert(_alertSub?.cancel);
  void setActionEnabled(bool enabled) => _alertSub?.setActionEnabled(enabled);
}
