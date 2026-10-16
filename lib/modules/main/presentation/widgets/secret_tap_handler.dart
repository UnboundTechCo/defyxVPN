import 'package:flutter/material.dart';
import 'package:defyx_vpn/shared/services/alert_service.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/logs_widget.dart';

class SecretTapHandler {
  int _secretTapCounter = 0;
  DateTime? _lastTapTime;
  final alertService = AlertService();

  void handleSecretTap(BuildContext context) {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inSeconds > 3) {
      _secretTapCounter = 0;
    }
    _lastTapTime = now;
    _secretTapCounter++;

    if (_secretTapCounter >= 7) {
      alertService.heartbeat();
      _secretTapCounter = 0;
      showAppLogsOverlay(context);
    }
  }

  void reset() {
    _secretTapCounter = 0;
    _lastTapTime = null;
  }
}
