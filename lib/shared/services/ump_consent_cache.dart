import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Cached UMP consent information
class ConsentCache {
  final ConsentStatus status;
  final bool canShowAds;
  final bool canRequestAds;
  final DateTime cachedAt;
  final Duration cacheValidity;

  ConsentCache({
    required this.status,
    required this.canShowAds,
    required this.canRequestAds,
    required this.cachedAt,
    this.cacheValidity = const Duration(hours: 12),
  });

  /// Check if cache is still valid
  bool get isValid {
    final age = DateTime.now().difference(cachedAt);
    return age < cacheValidity;
  }

  /// Get cache age in minutes
  int get ageInMinutes {
    return DateTime.now().difference(cachedAt).inMinutes;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'status': status.index,
      'canShowAds': canShowAds,
      'canRequestAds': canRequestAds,
      'cachedAt': cachedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory ConsentCache.fromJson(Map<String, dynamic> json) {
    return ConsentCache(
      status: ConsentStatus.values[json['status'] as int],
      canShowAds: json['canShowAds'] as bool,
      canRequestAds: json['canRequestAds'] as bool,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
    );
  }
}

/// Service to cache UMP consent status
class UmpConsentCacheService {
  static const String _cacheKey = 'ump_consent_cache';
  final ISecureStorage _storage;

  UmpConsentCacheService(this._storage);

  /// Save consent status to cache
  Future<void> cacheConsentStatus({
    required ConsentStatus status,
    required bool canShowAds,
    required bool canRequestAds,
  }) async {
    try {
      final cache = ConsentCache(
        status: status,
        canShowAds: canShowAds,
        canRequestAds: canRequestAds,
        cachedAt: DateTime.now(),
      );

      await _storage.writeMap(_cacheKey, cache.toJson());
      debugPrint('💾 UMP consent cached: ${status.name}, canShowAds=$canShowAds');
    } catch (e) {
      debugPrint('❌ Failed to cache UMP consent: $e');
    }
  }

  /// Load cached consent status
  Future<ConsentCache?> loadCachedConsentStatus() async {
    try {
      final json = await _storage.readMap(_cacheKey);
      if (json.isEmpty) {
        debugPrint('📭 No cached UMP consent found');
        return null;
      }

      final cache = ConsentCache.fromJson(json);
      
      if (!cache.isValid) {
        debugPrint('⏰ Cached UMP consent expired (${cache.ageInMinutes}m old)');
        await clearCache();
        return null;
      }

      debugPrint(
        '📦 Loaded cached UMP consent: ${cache.status.name}, age: ${cache.ageInMinutes}m',
      );
      return cache;
    } catch (e) {
      debugPrint('❌ Failed to load UMP consent cache: $e');
      return null;
    }
  }

  /// Clear consent cache
  Future<void> clearCache() async {
    try {
      await _storage.delete(_cacheKey);
      debugPrint('🗑️ UMP consent cache cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear UMP consent cache: $e');
    }
  }

  /// Check if we can skip consent request (cached and valid)
  Future<bool> canSkipConsentRequest() async {
    final cache = await loadCachedConsentStatus();
    if (cache == null || !cache.isValid) return false;

    // Skip if consent already obtained or not required
    return cache.status == ConsentStatus.obtained ||
           cache.status == ConsentStatus.notRequired;
  }

  /// Get cached ad show permission (fast path)
  Future<bool?> getCachedCanShowAds() async {
    final cache = await loadCachedConsentStatus();
    if (cache == null || !cache.isValid) return null;
    
    return cache.canShowAds;
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getStats() async {
    try {
      final cache = await loadCachedConsentStatus();
      if (cache == null) {
        return {'cached': false};
      }

      return {
        'cached': true,
        'status': cache.status.name,
        'canShowAds': cache.canShowAds,
        'canRequestAds': cache.canRequestAds,
        'ageMinutes': cache.ageInMinutes,
        'isValid': cache.isValid,
      };
    } catch (e) {
      debugPrint('❌ Failed to get UMP cache stats: $e');
      return {'cached': false, 'error': e.toString()};
    }
  }
}

/// Riverpod provider for UMP consent cache service
final umpConsentCacheServiceProvider = Provider<UmpConsentCacheService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return UmpConsentCacheService(storage);
});
