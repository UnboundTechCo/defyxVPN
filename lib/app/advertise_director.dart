import 'dart:io';
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
    // Desktop platforms always use internal ads (no AdMob support)
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      debugPrint('📍 Ad Manager - Desktop platform detected, using internal ads');
      return true;
    }

    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    debugPrint('📍 Ad Manager - Current Timezone: $currentTimeZone');

    final adversies =
        await ref.read(secureStorageProvider).readMap(apiAvertiseKey);

    if (adversies['api_advertise'] != null) {
      final advertiseMap = adversies['api_advertise'] as Map<String, dynamic>;
      
      // Check for timezone-specific ads only
      // If timezone matches → use internal ads
      // If no match → try AdMob first, "General" will be fallback when AdMob fails
      final hasTimezoneAds = advertiseMap.containsKey(currentTimeZone);
      if (hasTimezoneAds) {
        debugPrint('📍 Ad Manager - Has timezone-specific ads: $currentTimeZone');
        return true;
      }
      
      debugPrint('📍 Ad Manager - No timezone match, will try AdMob (General ads available as fallback)');
      debugPrint('📍 Ad Manager - Available keys: ${advertiseMap.keys.toList()}');
    } else {
      debugPrint('📍 Ad Manager - No advertise data found');
    }

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
      
      // Try timezone-specific ads first
      if (advertiseMap.containsKey(currentTimeZone)) {
        final adsData = advertiseMap[currentTimeZone] as List<dynamic>;
        debugPrint('📍 Ad Manager - Found ${adsData.length} timezone-specific ads');
        if (adsData.isNotEmpty) {
          final random = Random();
          final randomIndex = random.nextInt(adsData.length);
          final selectedAd = adsData[randomIndex] as List<dynamic>;

          if (selectedAd.length >= 2) {
            debugPrint('📍 Ad Manager - Selected timezone ad #$randomIndex');
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
        debugPrint('📍 Ad Manager - Using "General" fallback ads (${adsData.length} available)');
        if (adsData.isNotEmpty) {
          final random = Random();
          final randomIndex = random.nextInt(adsData.length);
          final selectedAd = adsData[randomIndex] as List<dynamic>;

          if (selectedAd.length >= 2) {
            debugPrint('📍 Ad Manager - Selected General ad #$randomIndex');
            return {
              'imageUrl': selectedAd[0] as String,
              'clickUrl': selectedAd[1] as String,
            };
          }
        }
      }
      
      debugPrint('📍 Ad Manager - No ads for timezone: $currentTimeZone');
      debugPrint('📍 Ad Manager - Available keys: ${advertiseMap.keys.toList()}');
    }
    
    debugPrint('📍 Ad Manager - Returning empty ad');
    // Return empty map - UI will handle showing "No ads available"
    return {'imageUrl': '', 'clickUrl': ''};
  }
}
