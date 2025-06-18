import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:defyx_vpn/modules/core/warp_plus.dart';
import 'package:defyx_vpn/modules/core/flow_line_controller.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/providers/logs_provider.dart';
import 'package:dio/dio.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/google_ads.dart';

Future<void> initializeAds() async {
  await MobileAds.instance.initialize();
}

final pingLoadingProvider = StateProvider<bool>((ref) => false);
final flagLoadingProvider = StateProvider<bool>((ref) => false);

final pingProvider = FutureProvider<String>((ref) async {
  final isLoading = ref.watch(pingLoadingProvider);
  if (isLoading) {
    final ping = await WarpPlus.getPing();
    ref.read(pingLoadingProvider.notifier).state = false;
    return ping;
  }
  return await WarpPlus.getPing();
});

final flagProvider = FutureProvider<String>((ref) async {
  final isLoading = ref.watch(flagLoadingProvider);
  if (isLoading) {
    final flag = await WarpPlus.getFlag();
    ref.read(flagLoadingProvider.notifier).state = false;
    return flag;
  }
  return await WarpPlus.getFlag();
});

class MainScreenLogic {
  final WidgetRef ref;

  MainScreenLogic(this.ref);

  Future<void> refreshPing() async {
    ref.read(pingLoadingProvider.notifier).state = true;
    ref.read(flagLoadingProvider.notifier).state = true;
  }

  Future<void> connectOrDisconnect() async {
    final connectionNotifier = ref.read(connectionStateProvider.notifier);
    final connectionState = ref.read(connectionStateProvider);
    final loggerNotifier = ref.read(loggerStateProvider.notifier);

    try {
      if (connectionState.status == ConnectionStatus.connected ||
          connectionState.status == ConnectionStatus.loading ||
          connectionState.status == ConnectionStatus.analyzing) {
        await WarpPlus.disconnect();
        connectionNotifier.setDisconnected();
        ref.read(FlowLineController.flowLineStateNotifier.notifier).state =
            false;
      } else {
        WarpPlus.clearWarpLogs(clearUILogs: false);
        connectionNotifier.setLoading();

        if (!await WarpPlus.checkNetwork()) {
          connectionNotifier.setNoInternet();
          return;
        }
        loggerNotifier.setScanning();
        await Future.delayed(const Duration(milliseconds: 100));
        final flowLineStatus = await FlowLineController.startFromConfig(ref);

        if (flowLineStatus != null && flowLineStatus['success'] == true) {
          await initializeAds();

          Vibration.vibrate(duration: 300);
          WarpPlus.fetchLogsForMemoryCleanup(ref);
          if (flowLineStatus['config']['psiphon'] == true) {
            connectionNotifier.setConnected();
            // Reset Google Ads timer when successfully connected
            ref.read(googleAdsProvider.notifier).resetTimer();
            refreshPing();
          } else {
            try {
              final dio = Dio();
              final response = await dio.get(
                'https://connectivity.cloudflareclient.com/cdn-cgi/trace',
                options: Options(
                  sendTimeout: const Duration(seconds: 5),
                  receiveTimeout: const Duration(seconds: 5),
                ),
              );
              if (response.data.contains('warp=on')) {
                connectionNotifier.setConnected();
                // Reset Google Ads timer when successfully connected
                ref.read(googleAdsProvider.notifier).resetTimer();
                refreshPing();
              }
            } catch (e) {
              WarpPlus.cancelLogCleanupTimer();
              connectionNotifier.setError();
              WarpPlus.disconnect();
            }
          }
        } else if (flowLineStatus != null &&
            flowLineStatus['errorCode'] == 108) {
        } else if (flowLineStatus != null &&
            flowLineStatus['errorCode'] == 109) {
        } else if (flowLineStatus != null &&
            flowLineStatus['errorCode'] == 103) {
          connectionNotifier.setNoInternet();
        } else {
          connectionNotifier.setError();
        }
      }
    } catch (e) {
      connectionNotifier.setDisconnected();
    }
  }

  Future<void> checkAndReconnect() async {
    final connectionState = ref.read(connectionStateProvider);
    if (connectionState.status == ConnectionStatus.connected) {
      await connectOrDisconnect();
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
}
