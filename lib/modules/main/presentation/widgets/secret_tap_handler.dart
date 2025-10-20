import 'package:flutter/material.dart';
import 'package:defyx_vpn/shared/services/vibration_service.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/logs_widget.dart';

class SecretTapHandler {
  int _secretTapCounter = 0;
  DateTime? _lastTapTime;
  final vibrationService = VibrationService();

  void handleSecretTap(BuildContext context) {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inSeconds > 3) {
      _secretTapCounter = 0;
    }
    _lastTapTime = now;
    _secretTapCounter++;

    if (_secretTapCounter >= 7) {
      vibrationService.vibrateHeartbeat();
      _secretTapCounter = 0;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: const Color.fromARGB(13, 0, 0, 0),
              child: const LogScreen(),
            ),
          );
        },
      );
    }
  }

  void reset() {
    _secretTapCounter = 0;
    _lastTapTime = null;
  }
}
