import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/introduction_dialog.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/logs_widget.dart';

class NativeMethodHandler {
  static const MethodChannel _channel = MethodChannel('com.defyx.vpn');

  static void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('NativeMethodHandler: Received ${call.method}');

    switch (call.method) {
      case 'openIntroduction':
        await _openIntroduction();
        break;
      case 'openSpeedTest':
        await _openSpeedTest();
        break;
      case 'openLogs':
        await _openLogs();
        break;
      default:
        debugPrint('NativeMethodHandler: Unknown method ${call.method}');
    }
  }

  static Future<void> _openIntroduction() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('NativeMethodHandler: Context unavailable');
      return;
    }

    context.go(DefyxVPNRoutes.main.route);
    await Future.delayed(const Duration(milliseconds: 300));

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => const IntroductionDialog(),
      );
    }
  }

  static Future<void> _openSpeedTest() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('NativeMethodHandler: Context unavailable');
      return;
    }

    context.go(DefyxVPNRoutes.speedTest.route);
  }

  static Future<void> _openLogs() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('NativeMethodHandler: Context unavailable');
      return;
    }

    context.go(DefyxVPNRoutes.main.route);
    await Future.delayed(const Duration(milliseconds: 300));

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => const Dialog(
          backgroundColor: Colors.transparent,
          child: LogPopupContent(),
        ),
      );
    }
  }
}
