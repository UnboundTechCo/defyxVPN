import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

class AdvertiseDirector {
  final WidgetRef ref;

  AdvertiseDirector(this.ref);

  static Future<bool> shouldUseInternalAds(WidgetRef ref) async {
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    debugPrint('📍 Ad Manager - Current Timezone: $currentTimeZone');

    final adversies =
        await ref.read(secureStorageProvider).readMap(apiAvertiseKey);

    if (adversies['api_advertise'] != null) {
      final advertiseMap = adversies['api_advertise'] as Map<String, dynamic>;
      final hasInternalAds = advertiseMap.containsKey(currentTimeZone);
      debugPrint('📍 Ad Manager - Has internal ads for timezone: $hasInternalAds');
      if (hasInternalAds) {
        debugPrint('📍 Ad Manager - Available timezones: ${advertiseMap.keys.toList()}');
      }
      return hasInternalAds;
    }

    debugPrint('📍 Ad Manager - No advertise data found');
    return false;
  }

  static Future<String> getCustomAdBanner(WidgetRef ref) async {
    final adData = await getRandomCustomAd(ref);
    return adData['imageUrl'] ?? '';
  }

  static Future<String> getCustomAdClickUrl(WidgetRef ref) async {
    final adData = await getRandomCustomAd(ref);
    return adData['clickUrl'] ?? '';
  }

  static Future<Map<String, String>> getRandomCustomAd(WidgetRef ref) async {
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    debugPrint('📍 Ad Manager - Getting ad for timezone: $currentTimeZone');

    final adversies =
        await ref.read(secureStorageProvider).readMap(apiAvertiseKey);

    if (adversies['api_advertise'] != null) {
      final advertiseMap = adversies['api_advertise'] as Map<String, dynamic>;
      if (advertiseMap.containsKey(currentTimeZone)) {
        final adsData = advertiseMap[currentTimeZone] as List<dynamic>;
        debugPrint('📍 Ad Manager - Found ${adsData.length} ads for timezone');
        if (adsData.isNotEmpty) {
          final random = Random();
          final randomIndex = random.nextInt(adsData.length);
          final selectedAd = adsData[randomIndex] as List<dynamic>;

          if (selectedAd.length >= 2) {
            debugPrint('📍 Ad Manager - Selected ad #$randomIndex');
            return {
              'imageUrl': selectedAd[0] as String,
              'clickUrl': selectedAd[1] as String,
            };
          }
        }
      } else {
        debugPrint('📍 Ad Manager - No ads for timezone: $currentTimeZone');
        debugPrint('📍 Ad Manager - Available timezones: ${advertiseMap.keys.toList()}');
      }
    }
    
    debugPrint('📍 Ad Manager - Returning empty ad');
    // Return empty map - UI will handle showing "No ads available"
    return {'imageUrl': '', 'clickUrl': ''};
  }
}
