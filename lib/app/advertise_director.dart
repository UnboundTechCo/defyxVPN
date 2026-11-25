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

  /// Whether AdMob is switched off on this device, or null while that cannot
  /// be known yet: on a fresh install the server settings that list where
  /// AdMob is off (`disabledAdmob`: "general" or time zone names) have not
  /// been saved yet.
  ///
  /// - Desktop: always off (no AdMob support); in-house ads only.
  /// - Mobile: off where `disabledAdmob` says so. Otherwise AdMob fills the
  ///   disconnected state and in-house ads the connected state.
  static Future<bool?> isAdMobDisabled(Ref ref) async {
    if (!(Platform.isAndroid || Platform.isIOS)) return true;

    final settings = await ref
        .read(flowlineServiceProvider)
        .getSavedFlowlineSettings();
    if (settings == null) return null;

    if (settings.disabledAdmob.contains("general")) return true;

    final String currentTimeZone = (await FlutterTimezone.getLocalTimezone())
        .identifier
        .toLowerCase();
    return settings.disabledAdmob.contains(currentTimeZone);
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
    final String currentTimeZone =
        (await FlutterTimezone.getLocalTimezone()).identifier;
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
