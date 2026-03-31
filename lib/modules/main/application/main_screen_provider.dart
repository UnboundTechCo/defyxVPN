import 'dart:async';

import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/modules/core/vpn.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:defyx_vpn/modules/core/network.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:version/version.dart';

final pingLoadingProvider = StateProvider<bool>((ref) => false);
final flagLoadingProvider = StateProvider<bool>((ref) => false);

final pingProvider = StateProvider<String>((ref) => '0');

final flagProvider = FutureProvider<String>((ref) async {
  final isLoading = ref.watch(flagLoadingProvider);
  final network = NetworkStatus();

  if (isLoading) {
    final flag = await network.getFlag();
    ref.read(flagLoadingProvider.notifier).state = false;
    return flag.toLowerCase();
  }
  return (await network.getFlag()).toLowerCase();
});

class MainScreenLogic {
  final WidgetRef ref;

  MainScreenLogic(this.ref);

  Future<void> refreshPing() async {
    await VPN(ProviderScope.containerOf(ref.context)).refreshPing();
  }

  Future<void> connectOrDisconnect() async {
    final connectionNotifier = ref.read(connectionStateProvider.notifier);

    try {
      final vpn = VPN(ProviderScope.containerOf(ref.context));
      await vpn.handleConnectionButton(ref);
    } catch (e) {
      connectionNotifier.setDisconnected();
    }
  }

  Future<void> checkAndReconnect() async {
    final connectionState = ref.read(connectionStateProvider);
    if (connectionState.status == ConnectionStatus.connected) {
      // await connectOrDisconnect();
    }
  }

  Future<void> checkAndShowPrivacyNotice(Future<void> Function() showDialog) async {
    final prefs = await SharedPreferences.getInstance();
    final bool privacyNoticeShown = prefs.getBool('privacy_notice_shown') ?? false;
    if (!privacyNoticeShown) {
      return showDialog();
    }
  }

  Future<void> markPrivacyNoticeShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_notice_shown', true);
  }

  Future<void> triggerAutoConnectIfEnabled() async {
    final container = ProviderScope.containerOf(ref.context);
    final prefs = await SharedPreferences.getInstance();
    final autoConnectEnabled = prefs.getBool('auto_connect_enabled') ?? false;

    if (autoConnectEnabled) {
      final connectionState = ref.read(connectionStateProvider);
      if (connectionState.status == ConnectionStatus.disconnected) {
        final vpn = VPN(container);
        await vpn.autoConnect();
      }
    }
  }

  Future<Map<String, dynamic>> checkForUpdate() async {
    final storage = ref.read(secureStorageProvider);

    final packageInfo = await PackageInfo.fromPlatform();
    final apiVersionParameters = await storage.readMap('api_version_parameters');

    final forceUpdate = apiVersionParameters['forceUpdate'] ?? false;

    final removeBuildNumber = apiVersionParameters['api_app_version']?.split('+').first ?? '0.0.0';

    final appVersion = Version.parse(packageInfo.version);
    final apiAppVersion = Version.parse(removeBuildNumber);

    final response = {
      'update': apiAppVersion > appVersion,
      'forceUpdate': forceUpdate,
      'changeLog': apiVersionParameters['changeLog'],
    };
    return response;
  }
}
