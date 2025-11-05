import 'dart:async';
import 'dart:io';

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

// Track if ping has been triggered at least once
final pingTriggeredProvider = StateProvider<bool>((ref) => false);
final flagTriggeredProvider = StateProvider<bool>((ref) => false);

// Windows-specific ping stream provider - only emits after first trigger
final windowsPingStreamProvider = StreamProvider.autoDispose<String?>((ref) {
  if (Platform.isWindows) {
    final network = NetworkStatus();
    final hasTriggered = ref.watch(pingTriggeredProvider);
    if (!hasTriggered) {
      // Don't emit anything until first trigger
      return Stream.value(null);
    }
    return network.pingStream;
  }
  return Stream.value(null);
});

// Windows-specific flag stream provider - only emits after first trigger
final windowsFlagStreamProvider = StreamProvider.autoDispose<String?>((ref) {
  if (Platform.isWindows) {
    final network = NetworkStatus();
    final hasTriggered = ref.watch(flagTriggeredProvider);
    if (!hasTriggered) {
      return Stream.value(null);
    }
    return network.flagStream;
  }
  return Stream.value(null);
});

final pingProvider = FutureProvider<String>((ref) async {
  final isLoading = ref.watch(pingLoadingProvider);
  final network = NetworkStatus();

  if (Platform.isWindows) {
    if (isLoading) {
      await network.triggerPing();
      ref.read(pingTriggeredProvider.notifier).state = true;
      ref.read(pingLoadingProvider.notifier).state = false;
      // Wait a moment for stream to update
      await Future.delayed(Duration(milliseconds: 100));
    }

    // Get latest value from stream
    final pingStream = ref.watch(windowsPingStreamProvider);
    return pingStream.when(
      data: (ping) => ping ?? "...",
      loading: () => "...",
      error: (_, __) => "0",
    );
  }

  // Non-Windows platforms use synchronous ping
  if (isLoading) {
    final ping = await network.getPing();
    ref.read(pingLoadingProvider.notifier).state = false;
    return ping;
  }
  return await network.getPing();
});

final flagProvider = FutureProvider<String>((ref) async {
  final isLoading = ref.watch(flagLoadingProvider);
  final network = NetworkStatus();

  if (Platform.isWindows) {
    if (isLoading) {
      await network.triggerFlag();
      ref.read(flagTriggeredProvider.notifier).state = true;
      ref.read(flagLoadingProvider.notifier).state = false;
      await Future.delayed(Duration(milliseconds: 100));
    }

    final flagStream = ref.watch(windowsFlagStreamProvider);
    return flagStream.when(
      data: (flag) => flag ?? "xx",
      loading: () => "xx",
      error: (_, __) => "xx",
    );
  }

  // Non-Windows platforms

  if (isLoading) {
    final flag = await network.getFlag();
    ref.read(flagLoadingProvider.notifier).state = false;
    return flag;
  }
  return await network.getFlag();
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

  Future<void> checkAndShowPrivacyNotice(Function showDialog) async {
    final prefs = await SharedPreferences.getInstance();
    final bool privacyNoticeShown =
        prefs.getBool('privacy_notice_shown') ?? false;
    if (!privacyNoticeShown) {
      showDialog();
    }
  }

  Future<void> markPrivacyNoticeShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_notice_shown', true);
  }

  Future<Map<String, dynamic>> checkForUpdate() async {
    final storage = ref.read(secureStorageProvider);

    final packageInfo = await PackageInfo.fromPlatform();
    final apiVersionParameters =
        await storage.readMap('api_version_parameters');

    final forceUpdate = apiVersionParameters['forceUpdate'] ?? false;

    final removeBuildNumber =
        apiVersionParameters['api_app_version']?.split('+').first ?? '0.0.0';

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
