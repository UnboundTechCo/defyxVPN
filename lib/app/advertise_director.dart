import 'dart:io';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

class AdvertiseDirector {
  final WidgetRef ref;

  AdvertiseDirector(this.ref);

  static Future<bool> shouldUseInternalAds(Ref ref) async {
    // STRATEGY SELECTION (for backward compatibility with desktop):
    // - Desktop (Windows/macOS/Linux) -> InternalAdStrategy only (no AdMob support)
    // - Iranian users -> InternalAdStrategy only (AdMob disabled for Iran)
    // - Mobile (Android/iOS) -> DUAL strategy approach:
    //     * GoogleAdStrategy handles AdMob ads (disconnected state ONLY)
    //     * InternalAdStrategy handles internal ads (connected state ONLY)
    //     * AdsWidget coordinates between the two strategies
    final flowlineSettings = await ref
        .read(flowlineServiceProvider)
        .getFlowlineSettings();

    if (flowlineSettings.disabledAdmob.contains("general")) {
      return true;
    }

    final String currentTimeZone = (await FlutterTimezone.getLocalTimezone())
        .toLowerCase();

    if (flowlineSettings.disabledAdmob.contains(currentTimeZone)) {
      return true;
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return true;
    }

    // Mobile platforms use DUAL strategy (GoogleAdStrategy + InternalAdStrategy)
    // AdsWidget automatically initializes both and routes based on connection state:
    //   - When CONNECTED: InternalAdStrategy shows internal ads (timezone-specific or General)
    //   - When DISCONNECTED: GoogleAdStrategy shows AdMob ads

    return false; // Mobile uses dual strategy (both GoogleAdStrategy + InternalAdStrategy)
  }

  static Future<String> getCustomAdBanner(Ref ref) async {
    final adData = await getRandomCustomAd(ref);
    return adData['imageUrl'] ?? '';
  }

  static Future<String> getCustomAdClickUrl(Ref ref) async {
    final adData = await getRandomCustomAd(ref);
    return adData['clickUrl'] ?? '';
  }

  static Future<Map<String, String>> getRandomCustomAd(Ref ref) async {
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    debugPrint('Ad Manager - Getting ad for timezone: $currentTimeZone');

    final adversies = await ref
        .read(secureStorageProvider)
        .readMap(apiAvertiseKey);

    if (adversies['api_advertise'] != null) {
      final advertiseMap = adversies['api_advertise'] as Map<String, dynamic>;

      // Try timezone-specific ads first
      if (advertiseMap.containsKey(currentTimeZone)) {
        final adsData = advertiseMap[currentTimeZone] as List<dynamic>;
        debugPrint(
          '📍 Ad Manager - Found ${adsData.length} timezone-specific ads',
        );
        if (adsData.isNotEmpty) {
          final random = Random();
          final randomIndex = random.nextInt(adsData.length);
          final selectedAd = adsData[randomIndex] as List<dynamic>;

          if (selectedAd.length >= 2) {
            debugPrint('Ad Manager - Selected timezone ad #$randomIndex');
            return {
              'imageUrl': selectedAd[0] as String,
              'clickUrl': selectedAd[1] as String,
            };
          }
        }
      }

      // Fallback to "General" ads if no timezone-specific ads
      if (advertiseMap.containsKey('General')) {
        final adsData = advertiseMap['General'] as List<dynamic>;
        debugPrint(
          '📍 Ad Manager - Using "General" fallback ads (${adsData.length} available)',
        );
        if (adsData.isNotEmpty) {
          final random = Random();
          final randomIndex = random.nextInt(adsData.length);
          final selectedAd = adsData[randomIndex] as List<dynamic>;

          if (selectedAd.length >= 2) {
            debugPrint('Ad Manager - Selected General ad #$randomIndex');
            return {
              'imageUrl': selectedAd[0] as String,
              'clickUrl': selectedAd[1] as String,
            };
          }
        }
      }
    }
    return {'imageUrl': '', 'clickUrl': ''};
  }
}
