import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Service to detect Huawei devices and check for Google Play Services availability
class HuaweiDeviceService {
  static const List<String> _huaweiManufacturers = [
    'huawei',
    'honor', // Honor is a sub-brand of Huawei
  ];

  static const List<String> _huaweiModelsWithoutGMS = [
    // Huawei devices released after May 2019 (trade ban) typically don't have GMS
    'mate 30',
    'mate 40',
    'mate 50',
    'mate x2',
    'mate xs',
    'p40',
    'p50',
    'p60',
    'nova 7',
    'nova 8',
    'nova 9',
    'nova 10',
    'nova 11',
    'nova 12',
    // Add more models as needed
  ];

  /// Check if the current device is a Huawei device
  static Future<bool> isHuaweiDevice() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      
      final String manufacturer = androidInfo.manufacturer.toLowerCase();
      final String brand = androidInfo.brand.toLowerCase();
      
      return _huaweiManufacturers.contains(manufacturer) || 
             _huaweiManufacturers.contains(brand);
    } catch (e) {
      debugPrint('Error checking if device is Huawei: $e');
      return false;
    }
  }

  /// Check if the device likely has Google Play Services
  static Future<bool> hasGooglePlayServices() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      
      final String manufacturer = androidInfo.manufacturer.toLowerCase();
      final String model = androidInfo.model.toLowerCase();
      
      // If it's a Huawei device, check if it's a model known to not have GMS
      if (_huaweiManufacturers.contains(manufacturer)) {
        // Check if it's a model known to not have GMS
        for (String modelWithoutGMS in _huaweiModelsWithoutGMS) {
          if (model.contains(modelWithoutGMS.toLowerCase())) {
            return false;
          }
        }
        
        // For older Huawei devices or unknown models, try to detect GMS availability
        return await _checkGooglePlayServicesAvailability();
      }
      
      // For non-Huawei devices, assume Google Play Services are available
      return true;
    } catch (e) {
      debugPrint('Error checking Google Play Services availability: $e');
      return false;
    }
  }

  /// Try to check Google Play Services availability using Google Mobile Ads
  static Future<bool> _checkGooglePlayServicesAvailability() async {
    try {
      // Try to initialize Google Mobile Ads to check if GMS is available
      // This will throw an exception if Google Play Services are not available
      final initializeCompleter = await MobileAds.instance.initialize();
      
      // If we get here without an exception, GMS is likely available
      return initializeCompleter.adapterStatuses.isNotEmpty;
    } catch (e) {
      debugPrint('Google Play Services not available: $e');
      return false;
    }
  }

  /// Check if device should use internal ads (Huawei devices without GMS)
  static Future<bool> shouldUseInternalAds() async {
    final isHuawei = await isHuaweiDevice();
    if (!isHuawei) {
      return false;
    }

    final hasGMS = await hasGooglePlayServices();
    return !hasGMS;
  }

  /// Get device information for debugging purposes
  static Future<Map<String, String>> getDeviceInfo() async {
    if (!Platform.isAndroid) {
      return {'platform': 'not_android'};
    }

    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      
      return {
        'manufacturer': androidInfo.manufacturer,
        'brand': androidInfo.brand,
        'model': androidInfo.model,
        'device': androidInfo.device,
        'androidVersion': androidInfo.version.release,
        'sdkInt': androidInfo.version.sdkInt.toString(),
        'isHuawei': (await isHuaweiDevice()).toString(),
        'hasGMS': (await hasGooglePlayServices()).toString(),
      };
    } catch (e) {
      debugPrint('Error getting device info: $e');
      return {'error': e.toString()};
    }
  }

  /// Log device information for debugging
  static Future<void> logDeviceInfo() async {
    if (kDebugMode) {
      final deviceInfo = await getDeviceInfo();
      debugPrint('=== Device Information ===');
      deviceInfo.forEach((key, value) {
        debugPrint('$key: $value');
      });
      debugPrint('=========================');
    }
  }
}