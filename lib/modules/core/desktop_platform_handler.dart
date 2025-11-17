import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/introduction_dialog.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/logs_widget.dart';
import 'package:defyx_vpn/shared/services/alert_service.dart';
import 'package:defyx_vpn/modules/core/vpn.dart';

class DesktopPlatformHandler {
  static const MethodChannel _channel = MethodChannel('com.defyx.vpn');

  static void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('DesktopPlatformHandler: Received ${call.method}');

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
      case 'openPreferences':
        await _openPreferences();
        break;
      case 'setSoundEffect':
        _setSoundEffect(call.arguments);
        break;
      case 'setAutoConnect':
        _setAutoConnect(call.arguments);
        break;
      case 'triggerAutoConnect':
        await _triggerAutoConnect();
        break;
      case 'setStartMinimized':
        break;
      case 'setForceClose':
        break;
      default:
        debugPrint('DesktopPlatformHandler: Unknown method ${call.method}');
    }
  }

  static Future<void> _openIntroduction() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('DesktopPlatformHandler: Context unavailable');
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
      debugPrint('DesktopPlatformHandler: Context unavailable');
      return;
    }

    context.go(DefyxVPNRoutes.speedTest.route);
  }

  static Future<void> _openLogs() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('DesktopPlatformHandler: Context unavailable');
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

  static Future<void> _openPreferences() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('DesktopPlatformHandler: Context unavailable');
      return;
    }

    context.go(DefyxVPNRoutes.settings.route);
  }

  static void _setSoundEffect(dynamic arguments) {
    if (arguments is Map) {
      final value = arguments['value'] as bool? ?? true;
      AlertService().setActionEnabled(value);
      debugPrint('DesktopPlatformHandler: Sound effect set to $value');
    }
  }

  static void _setAutoConnect(dynamic arguments) {
    if (arguments is Map) {
      final value = arguments['value'] as bool? ?? false;
      debugPrint('DesktopPlatformHandler: Auto-connect set to $value');
    }
  }

  static Future<void> _triggerAutoConnect() async {
    debugPrint('DesktopPlatformHandler: Triggering auto-connect');

    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('DesktopPlatformHandler: Context unavailable for auto-connect');
      return;
    }

    await Future.delayed(const Duration(milliseconds: 1000));

    if (!context.mounted) {
      debugPrint('DesktopPlatformHandler: Context no longer mounted for auto-connect');
      return;
    }

    try {
      final container = ProviderScope.containerOf(context);

      final vpn = VPN(container);
      await vpn.autoConnect();

      debugPrint('DesktopPlatformHandler: Auto-connect triggered successfully');
    } catch (e) {
      debugPrint('DesktopPlatformHandler: Error during auto-connect: $e');
    }
  }
}
