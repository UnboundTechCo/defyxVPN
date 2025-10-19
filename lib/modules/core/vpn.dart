import 'dart:async';
import 'dart:io';

import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/modules/core/log.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/main/application/main_screen_provider.dart';
import 'package:defyx_vpn/modules/settings/providers/settings_provider.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/providers/flow_line_provider.dart';
import 'package:defyx_vpn/shared/providers/group_provider.dart';
import 'package:defyx_vpn/shared/providers/logs_provider.dart';
import 'package:defyx_vpn/shared/services/vibration_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';

class VPN {
  static final VPN _instance = VPN._internal();
  final log = Log();
  final vibrationService = VibrationService();

  factory VPN(ProviderContainer container) {
    _instance._init(container);
    return _instance;
  }

  VPN._internal();

  final _vpnBridge = VpnBridge();
  final _eventChannel = EventChannel("com.defyx.progress_events");

  Stream<String> get vpnUpdates =>
      _eventChannel.receiveBroadcastStream().map((event) => event.toString());

  bool _initialized = false;
  ProviderContainer? _container;
  StreamSubscription<String>? _vpnSub;

  void _init(ProviderContainer container) {
    if (_initialized) return;
    _initialized = true;
    _container = container;

    vibrationService.init();

    log.logAppVersion();
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final offsetInHours = offset.inMinutes / 60.0;
    _vpnBridge.setTimezone(offsetInHours.toString());
    vpnUpdates.listen((msg) {
      _handleVPNUpdates(msg);
    });
  }

  void dispose() {
    _vpnSub?.cancel();
  }

  void _handleVPNUpdates(String msg) {
    final ref = _container!;
    final loggerNotifier = ref.read(loggerStateProvider.notifier);
    final groupNotifier = ref.read(groupStateProvider.notifier);

    if (msg.startsWith("Data: Config index: ")) {
      final configIndex = msg.replaceAll("Data: Config index: ", "");
      final step = int.parse(configIndex);
      _setConnectionStep(step);
      loggerNotifier.setConnecting();
      
      if (step > 1) {
        vibrationService.vibrateHeartbeat();
      }
    }

    if (msg.startsWith("Data: VPN connected")) {
      _onSuccessConnect();
    }
    if (msg.startsWith("Data: VPN failed")) {
      _onFailerConnect();
    }
    if (msg.startsWith("Data: VPN cancelled")) {
      _closeTunnel();
    }
    if (msg.startsWith("Data: VPN group failed")) {
      loggerNotifier.setSwitchingMethod();
    }
    if (msg.startsWith("Data: VPN stopped")) {
      _closeTunnel();
    }
    if (msg.startsWith("Data: Config label: ")) {
      final configLabel = msg.replaceAll("Data: Config label: ", "");
      _vpnBridge.setConnectionMethod(configLabel);
      groupNotifier.setGroupName(configLabel);
    }

    if (msg.startsWith("Data: Config Numbers: ")) {
      final configIndex = msg.replaceAll("Data: Config Numbers: ", "");
      _setConnectionTotalSteps(int.parse(configIndex));
    }

    if (msg.contains("VPN Service Destroyed")) {
      _onTunnelClosed();
    }
    if (msg.contains("Start VPN Service")) {
      _connect();
    }

    log.addLog(msg);
  }

  Future<void> _connect() async {
    final connectionNotifier =
        _container?.read(connectionStateProvider.notifier);
    final loggerNotifier = _container?.read(loggerStateProvider.notifier);
    final settings = _container?.read(settingsProvider.notifier);

    _setConnectionStep(1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      connectionNotifier?.setLoading();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      connectionNotifier?.setAnalyzing();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loggerNotifier?.setLoading();
    });

    vibrationService.vibrateHeartbeat();

    if (!await _checkNetwork()) {
      connectionNotifier?.setNoInternet();
      vibrationService.vibrateError();
      return;
    }

    final isAccepted = await _grantVpnPermission();

    if (!isAccepted!) {
      connectionNotifier?.setDisconnected();
      return;
    }

    final flowLineStorage =
        await _container?.read(secureStorageProvider).read('flowLine') ?? "";

    final pattern = settings?.getPattern()??"";
    await _vpnBridge.startVPN(flowLineStorage, pattern);
  }

  Future<void> _onFailerConnect() async {
    final connectionNotifier =
        _container?.read(connectionStateProvider.notifier);

    connectionNotifier?.setError();
    await _vpnBridge.disconnectVpn();
    vibrationService.vibrateError();
  }

  Future<void> _onSuccessConnect() async {
    final connectionNotifier =
        _container?.read(connectionStateProvider.notifier);
    final connectionState = _container?.read(connectionStateProvider);
    if (connectionState?.status != ConnectionStatus.analyzing) {
      return;
    }

    await _createTunnel();
    connectionNotifier?.setConnected();
    await _refreshPing();
    vibrationService.vibrateSuccess();
    await _container?.read(flowlineServiceProvider).saveFlowline();
  }

  Future<void> _refreshPing() async {
    _container?.read(pingLoadingProvider.notifier).state = true;
    _container?.read(flagLoadingProvider.notifier).state = true;
  }

  Future<void> _stopVPN(WidgetRef ref) async {
    final connectionNotifier = ref.read(connectionStateProvider.notifier);
    connectionNotifier.setDisconnecting();
    await _vpnBridge.stopVPN();
    _clearData(ref);
    connectionNotifier.setDisconnected();
  }

  Future<void> _disconnect(WidgetRef ref) async {
    final connectionNotifier = ref.read(connectionStateProvider.notifier);
    connectionNotifier.setDisconnecting();
    await _vpnBridge.disconnectVpn();
    _clearData(ref);
    connectionNotifier.setDisconnected();
  }

  Future<void> _closeTunnel() async {
    final connectionNotifier =
        _container?.read(connectionStateProvider.notifier);
    if (Platform.isIOS) {
      await _vpnBridge.disconnectVpn();
    } else if (Platform.isAndroid) {
      await _vpnBridge.stopTun2Socks();
    }
    connectionNotifier?.setDisconnected();
  }


  Future<void> _onTunnelClosed() async {
    final connectionNotifier =
        _container?.read(connectionStateProvider.notifier);
    await _vpnBridge.stopVPN();
    await _vpnBridge.stopTun2Socks();
    connectionNotifier?.setDisconnected();
  }

  Future<bool?> _grantVpnPermission() async {
    switch (Platform.operatingSystem) {
      case 'android':
        return await _vpnBridge.grantVpnPermission();
      case "ios":
        return await _vpnBridge.connectVpn();
      default:
        return false;
    }
  }

  Future<void> _createTunnel() async {
    switch (Platform.operatingSystem) {
      case 'android':
        await _vpnBridge.connectVpn();
        break;
      case "ios":
        await _vpnBridge.startTun2socks();
        break;
    }
  }

  Future<bool> _checkNetwork() async {
    try {
      final dio = Dio();
      await dio.get(
        'https://www.google.com/generate_204',
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Error checking network: $e');
      return false;
    }
  }

  void _setConnectionStep(int step) {
    _container?.read(flowLineStepProvider.notifier).setStep(step);
  }

  void _setConnectionTotalSteps(int totalSteps) {
    _container?.read(flowLineStepProvider.notifier).setTotalSteps(totalSteps);
  }

  void _clearData(WidgetRef ref) {
    final groupNotifier = ref.read(groupStateProvider.notifier);
    groupNotifier.setGroupName("");
    _setConnectionTotalSteps(0);
    _setConnectionStep(0);
  }

  Future<void> handleConnectionButton(WidgetRef ref) async {
    final connectionState = ref.read(connectionStateProvider);
    switch (connectionState.status) {
      case ConnectionStatus.connected:
        await _disconnect(ref);
        return;
      case ConnectionStatus.loading:
      case ConnectionStatus.analyzing:
        await _stopVPN(ref);
        return;
      case ConnectionStatus.disconnected:
      case ConnectionStatus.error:
      case ConnectionStatus.noInternet:
        await _connect();
        return;
      default:
        break;
    }
  }

  Future<void> getVPNStatus() async {
    final connectionNotifier =
        _container?.read(connectionStateProvider.notifier);
    final isTunnelRunning =
        await _vpnBridge.isTunnelRunning();
    if (isTunnelRunning) {
      connectionNotifier?.setConnected();
    } else {
      connectionNotifier?.setDisconnected();
    }
  }
}
