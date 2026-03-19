import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/modules/core/log.dart';
import 'package:defyx_vpn/modules/core/network.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/main/application/main_screen_provider.dart';
import 'package:defyx_vpn/modules/settings/providers/settings_provider.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/providers/flow_line_provider.dart';
import 'package:defyx_vpn/shared/providers/group_provider.dart';
import 'package:defyx_vpn/shared/providers/logs_provider.dart';
import 'package:defyx_vpn/shared/services/alert_service.dart';
import 'package:defyx_vpn/shared/services/firebase_analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:defyx_vpn/core/data/local/vpn_data/vpn_data.dart';

class VPN {
  static final VPN _instance = VPN._internal();
  final log = Log();
  final analyticsService = FirebaseAnalyticsService();
  final alertService = AlertService();

  factory VPN(ProviderContainer container) {
    _instance._init(container);
    return _instance;
  }

  VPN._internal();
  String? _lastRoute;

  final _vpnBridge = VpnBridge();
  final _networkStatus = NetworkStatus();
  final _eventChannel = EventChannel("com.defyx.progress_events");

  Stream<String> get vpnUpdates =>
      _eventChannel.receiveBroadcastStream().map((event) => event.toString());

  bool _initialized = false;
  ProviderContainer? _container;
  StreamSubscription<String>? _vpnSub;
  DateTime? _connectionStartTime;

  void _init(ProviderContainer container) {
    if (_initialized) return;
    _initialized = true;
    _container = container;

    _container?.read(settingsProvider.notifier).saveState();

    alertService.init();
    _loadChangeRootListener();
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

  Future<void> autoConnect() async {
    final connectionState = _container?.read(connectionStateProvider);

    if (connectionState?.status == ConnectionStatus.disconnected) {
      log.addLog('[INFO] Auto-connect triggered');
      await _connect();
    } else {
      log.addLog(
          '[INFO] Auto-connect skipped - already connected or connecting');
    }
  }

  void _loadChangeRootListener() {
    final router = _container?.read(routerProvider);
    router?.routeInformationProvider.addListener(() {
      final currentRoute = _container?.read(currentRouteProvider);
      if (currentRoute == _lastRoute) {
        return;
      }
      _lastRoute = currentRoute;
      if (currentRoute == DefyxVPNRoutes.main.route) {
        _updatePing();
      }
    });
  }

  void _handleVPNUpdates(String msg) {
    final ref = _container!;
    final loggerNotifier = ref.read(loggerStateProvider.notifier);
    final groupNotifier = ref.read(groupStateProvider.notifier);

    // Try to parse as JSON event
    try {
      final jsonData = jsonDecode(msg);
      if (jsonData is Map && jsonData.containsKey('event')) {
        final event = jsonData['event'] as String;
        final data = jsonData['data'] as Map<String, dynamic>? ?? {};

        switch (event) {
          case 'STEP_PROGRESS':
            final step = data['step'] as int? ?? 0;
            final total = data['total'] as int? ?? 0;
            _setConnectionStep(step);
            if (total > 0) _setConnectionTotalSteps(total);
            loggerNotifier.setConnecting();
            if (step > 1) alertService.heartbeat();
            break;

          case 'CONFIG_INFO':
            if (data.containsKey('label')) {
              final configLabel = data['label'] as String;
              _vpnBridge.setConnectionMethod(configLabel);
              groupNotifier.setGroupName(configLabel);
            }
            if (data.containsKey('totalSteps')) {
              _setConnectionTotalSteps(data['totalSteps'] as int);
            }
            break;

          case 'TUNNEL_CONNECTED':
            _onSuccessConnect();
            break;

          case 'TUNNEL_FAILED':
            _onFailerConnect();
            break;

          case 'VPN_CANCELLED':
            _closeTunnel();
            break;

          case 'GROUP_FAILED':
            loggerNotifier.setSwitchingMethod();
            break;

          case 'VPN_STOPPED':
            _closeTunnel();
            break;

          case 'VPN_CONNECTING':
            _onLoading();
            break;
        }
        
        log.addLog(msg);
        return;
      }
    } catch (e) {
      // Not a JSON event, continue to legacy handling
    }

    // Legacy log message handling (for backward compatibility)
    if (msg.startsWith("Data: Firebase ")) {
      final message = msg.replaceAll("Data: Firebase ", "");
      return _sendCoreFirebaseMessage(message);
    }

    if (msg.contains("VPN Service Destroyed")) {
      _onTunnelClosed();
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
      loggerNotifier?.setLoading();
    });

    alertService.heartbeat();

    final networkIsConnected = await _networkStatus.checkConnectivity();
    if (!networkIsConnected) {
      connectionNotifier?.setNoInternet();
      alertService.error();
      return;
    }

    final isAccepted = await _grantVpnPermission();
    if (!isAccepted!) {
      connectionNotifier?.setDisconnected();
      return;
    }

    final flowLineStorage =
        await _container?.read(secureStorageProvider).read('flowLine') ?? "";
    final pattern = settings?.getPattern() ?? "";

    final isDeep =
        _container?.read(settingsProvider.notifier).isDeepScanEnabled() ??
            false;
    _connectionStartTime = DateTime.now();
    analyticsService.logVpnConnectAttempt(pattern.isEmpty ? 'auto' : pattern);

    await _vpnBridge.startVPN(flowLineStorage, pattern, isDeep);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      connectionNotifier?.setAnalyzing();
    });
  }

  Future<void> _onFailerConnect() async {
    final connectionNotifier =
        _container?.read(connectionStateProvider.notifier);

    connectionNotifier?.setError();
    await _vpnBridge.disconnectVpn();
    alertService.error();
  }

  Future<void> _onSuccessConnect() async {
    final connectionNotifier =
        _container?.read(connectionStateProvider.notifier);
    final connectionState = _container?.read(connectionStateProvider);
    final vpnData = await _container?.read(vpnDataProvider.future);
    if (connectionState?.status != ConnectionStatus.analyzing) {
      return;
    }

    // Note: Tunnel creation is now automatic via PROXY_READY event on both iOS and Android
    connectionNotifier?.setConnected();
    vpnData?.enableVPN();
    await refreshPing();
    alertService.success();

    final settings = _container?.read(settingsProvider.notifier);
    final groupState = _container?.read(groupStateProvider);
    final pattern = settings?.getPattern() ?? "auto";

    int connectionDuration = 0;
    if (_connectionStartTime != null) {
      connectionDuration =
          DateTime.now().difference(_connectionStartTime!).inSeconds;
      _connectionStartTime = null;
    }

    analyticsService.logVpnConnected(
        pattern, groupState?.groupName, connectionDuration);


    await _container?.read(flowlineServiceProvider).saveFlowline(offlineMode: false);
  }

  Future<void> _onLoading() async {
    final connectionNotifier =
        _container?.read(connectionStateProvider.notifier);
    final loggerNotifier = _container?.read(loggerStateProvider.notifier);

    final vpnData = await _container?.read(vpnDataProvider.future);

    loggerNotifier?.setLoading();
    connectionNotifier?.setAnalyzing();
    await vpnData?.disableVPN();
  }

  Future<void> refreshPing() async {
    _container?.read(flagLoadingProvider.notifier).state = true;
    _container?.read(pingLoadingProvider.notifier).state = true;
    _container?.read(pingProvider.notifier).state =
        await _networkStatus.getPing();
    _container?.read(pingLoadingProvider.notifier).state = false;
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
    final vpnData = await _container?.read(vpnDataProvider.future);
    connectionNotifier.setDisconnecting();
    await _vpnBridge.disconnectVpn();
    _clearData(ref);
    await vpnData?.disableVPN();
    connectionNotifier.setDisconnected();
    analyticsService.logVpnDisconnected();
  }

  Future<void> _closeTunnel() async {
    final connectionNotifier =
        _container?.read(connectionStateProvider.notifier);
    final vpnData = await _container?.read(vpnDataProvider.future);
    connectionNotifier?.setDisconnecting();
    if (Platform.isIOS) {
      await _vpnBridge.disconnectVpn();
    }
    await vpnData?.disableVPN();
    connectionNotifier?.setDisconnected();
    analyticsService.logVpnDisconnected();
  }

  Future<void> _onTunnelClosed() async {
    final connectionNotifier =
        _container?.read(connectionStateProvider.notifier);
    connectionNotifier?.setDisconnecting();
    final vpnData = await _container?.read(vpnDataProvider.future);
    await _vpnBridge.stopVPN();
    await vpnData?.disableVPN();
    connectionNotifier?.setDisconnected();
  }

  Future<bool?> _grantVpnPermission() async {
    switch (Platform.operatingSystem) {
      case 'android':
        return await _vpnBridge.grantVpnPermission();
      case "ios":
        return await _vpnBridge.connectVpn();
      case "windows":
        return await _vpnBridge.grantVpnPermission();
      default:
        return false;
    }
  }

  void _setConnectionStep(int step) {
    _container?.read(flowLineProvider.notifier).setStep(step);
  }

  void _setConnectionTotalSteps(int totalSteps) {
    _container?.read(flowLineProvider.notifier).setTotalSteps(totalSteps);
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
      case ConnectionStatus.analyzing:
        await _stopVPN(ref);
        return;
      case ConnectionStatus.disconnected:
      case ConnectionStatus.error:
      case ConnectionStatus.noInternet:
        await _connect();
        return;
      case ConnectionStatus.loading:
      default:
        break;
    }
  }

  Future<void> getVPNStatus() async {
    final status = await _vpnBridge.getVpnStatus();
    log.addLog("VPN status: $status");
    final connectionNotifier =
        _container?.read(connectionStateProvider.notifier);
    if (status == "connected") {
      connectionNotifier?.setConnected();
      await refreshPing();
    } else {
      connectionNotifier?.setDisconnected();
    }
  }

  Future<void> initVPN() async {
    _container?.read(settingsLoadingProvider.notifier).state = true;
    await _container?.read(flowlineServiceProvider).saveFlowline(offlineMode: true);
    await _vpnBridge.setAsnName();
    await _container?.read(flowlineServiceProvider).saveFlowline(offlineMode: false);
    _container?.read(settingsLoadingProvider.notifier).state = false;
  }

  Future<void> _updatePing() async {
    final connectionState = _container?.read(connectionStateProvider);
    if (connectionState?.status != ConnectionStatus.connected) {
      return;
    }

    _container?.read(pingProvider.notifier).state =
        await _networkStatus.getPing();
  }

  void _sendCoreFirebaseMessage(String message) {
    Map<String, dynamic> jsonData = jsonDecode(message);
    final title = jsonData["title"] ?? "Unknown";
    jsonData.remove("title");
    final Map<String, String> stringMap =
        jsonData.map((key, value) => MapEntry(key, value.toString()));
    analyticsService.logCoreData(title, stringMap);
  }
}
