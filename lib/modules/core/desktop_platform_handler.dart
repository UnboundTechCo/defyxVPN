import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/introduction_dialog.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/logs_widget.dart';
import 'package:defyx_vpn/shared/services/alert_service.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';

final trayConnectionToggleTriggerProvider =
    NotifierProvider<TrayConnectionToggleTriggerNotifier, int>(
      TrayConnectionToggleTriggerNotifier.new,
    );

class TrayConnectionToggleTriggerNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

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
      case 'setStartMinimized':
        break;
      case 'setForceClose':
        break;
      case 'handleConnectionStatusClick':
        await _handleConnectionStatusClick(call.arguments);
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

  static void _setAutoConnect(dynamic arguments) async {
    if (arguments is Map) {
      final value = arguments['value'] as bool? ?? false;
      debugPrint('DesktopPlatformHandler: Auto-connect set to $value');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_connect_enabled', value);
    }
  }

  static Future<void> _handleConnectionStatusClick(dynamic arguments) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('DesktopPlatformHandler: Context unavailable');
      return;
    }

    context.go(DefyxVPNRoutes.main.route);
    await Future.delayed(const Duration(milliseconds: 300));

    if (!context.mounted) return;

    String? status;
    if (arguments is Map) {
      status = arguments['status'] as String?;
    }

    debugPrint('DesktopPlatformHandler: Connection status click - status: $status');

    final container = ProviderScope.containerOf(context);
    final connectionState = container.read(connectionStateProvider);

    if (connectionState.status == ConnectionStatus.analyzing ||
        connectionState.status == ConnectionStatus.loading) {
      debugPrint('DesktopPlatformHandler: VPN is connecting, showing home screen only');
      return;
    }

    if (connectionState.status == ConnectionStatus.connected ||
        connectionState.status == ConnectionStatus.disconnected) {
      debugPrint('DesktopPlatformHandler: Triggering VPN toggle');

      try {
        container
            .read(trayConnectionToggleTriggerProvider.notifier)
            .increment();
      } catch (e) {
        debugPrint('DesktopPlatformHandler: Error triggering toggle - $e');
      }
    }
  }
}
