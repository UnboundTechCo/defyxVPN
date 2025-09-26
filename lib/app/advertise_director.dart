import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

class AdvertiseDirector {
  final WidgetRef ref;

  AdvertiseDirector(this.ref);

  static Future<bool> shouldUseInternalAds(WidgetRef ref) async {
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();

    final adversies =
        await ref.read(secureStorageProvider).readMap(apiAvertiseKey);

    if (adversies['api_advertise'] != null) {
      final advertiseMap = adversies['api_advertise'] as Map<String, dynamic>;
      return advertiseMap.containsKey(currentTimeZone);
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

    final adversies =
        await ref.read(secureStorageProvider).readMap(apiAvertiseKey);

    if (adversies['api_advertise'] != null) {
      final advertiseMap = adversies['api_advertise'] as Map<String, dynamic>;
      if (advertiseMap.containsKey(currentTimeZone)) {
        final adsData = advertiseMap[currentTimeZone] as List<dynamic>;
        if (adsData.isNotEmpty) {
          final random = Random();
          final randomIndex = random.nextInt(adsData.length);
          final selectedAd = adsData[randomIndex] as List<dynamic>;

          if (selectedAd.length >= 2) {
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
