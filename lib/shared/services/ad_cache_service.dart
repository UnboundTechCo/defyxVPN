import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ad metadata for caching
class AdMetadata {
  final String adUnitId;
  final DateTime loadedAt;
  final int impressionCount;
  final DateTime? lastImpressionAt;
  final int loadAttempts;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final bool isPersonalized;

  AdMetadata({
    required this.adUnitId,
    required this.loadedAt,
    this.impressionCount = 0,
    this.lastImpressionAt,
    this.loadAttempts = 1,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.isPersonalized = true,
  });

  /// Check if ad is stale (older than 15 minutes)
  bool get isStale {
    final age = DateTime.now().difference(loadedAt);
    return age.inMinutes >= 15;
  }

  /// Get age in minutes
  int get ageInMinutes {
    return DateTime.now().difference(loadedAt).inMinutes;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'adUnitId': adUnitId,
      'loadedAt': loadedAt.toIso8601String(),
      'impressionCount': impressionCount,
      'lastImpressionAt': lastImpressionAt?.toIso8601String(),
      'loadAttempts': loadAttempts,
      'lastErrorCode': lastErrorCode,
      'lastErrorMessage': lastErrorMessage,
      'isPersonalized': isPersonalized,
    };
  }

  /// Create from JSON
  factory AdMetadata.fromJson(Map<String, dynamic> json) {
    return AdMetadata(
      adUnitId: json['adUnitId'] as String,
      loadedAt: DateTime.parse(json['loadedAt'] as String),
      impressionCount: json['impressionCount'] as int? ?? 0,
      lastImpressionAt: json['lastImpressionAt'] != null
          ? DateTime.parse(json['lastImpressionAt'] as String)
          : null,
      loadAttempts: json['loadAttempts'] as int? ?? 1,
      lastErrorCode: json['lastErrorCode'] as String?,
      lastErrorMessage: json['lastErrorMessage'] as String?,
      isPersonalized: json['isPersonalized'] as bool? ?? true,
    );
  }

  /// Create copy with updated fields
  AdMetadata copyWith({
    String? adUnitId,
    DateTime? loadedAt,
    int? impressionCount,
    DateTime? lastImpressionAt,
    int? loadAttempts,
    String? lastErrorCode,
    String? lastErrorMessage,
    bool? isPersonalized,
  }) {
    return AdMetadata(
      adUnitId: adUnitId ?? this.adUnitId,
      loadedAt: loadedAt ?? this.loadedAt,
      impressionCount: impressionCount ?? this.impressionCount,
      lastImpressionAt: lastImpressionAt ?? this.lastImpressionAt,
      loadAttempts: loadAttempts ?? this.loadAttempts,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      isPersonalized: isPersonalized ?? this.isPersonalized,
    );
  }
}

/// Service to cache ad metadata in secure storage
class AdCacheService {
  static const String _cacheKey = 'ad_metadata_cache';
  final ISecureStorage _storage;

  AdCacheService(this._storage);

  /// Save ad metadata to cache
  Future<void> saveMetadata(AdMetadata metadata) async {
    try {
      final json = metadata.toJson();
      await _storage.writeMap(_cacheKey, json);
      debugPrint('💾 Ad metadata cached: ${metadata.adUnitId}');
    } catch (e) {
      debugPrint('❌ Failed to cache ad metadata: $e');
    }
  }

  /// Load ad metadata from cache
  Future<AdMetadata?> loadMetadata() async {
    try {
      final json = await _storage.readMap(_cacheKey);
      if (json.isEmpty) {
        debugPrint('📭 No cached ad metadata found');
        return null;
      }

      final metadata = AdMetadata.fromJson(json);
      debugPrint(
        '📦 Loaded cached ad metadata: ${metadata.adUnitId}, age: ${metadata.ageInMinutes}m',
      );
      return metadata;
    } catch (e) {
      debugPrint('❌ Failed to load ad metadata: $e');
      return null;
    }
  }

  /// Clear ad metadata cache
  Future<void> clearMetadata() async {
    try {
      await _storage.delete(_cacheKey);
      debugPrint('🗑️ Ad metadata cache cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear ad metadata: $e');
    }
  }

  /// Record ad impression
  Future<void> recordImpression() async {
    try {
      final metadata = await loadMetadata();
      if (metadata == null) {
        debugPrint('⚠️ Cannot record impression - no cached metadata');
        return;
      }

      final updated = metadata.copyWith(
        impressionCount: metadata.impressionCount + 1,
        lastImpressionAt: DateTime.now(),
      );

      await saveMetadata(updated);
      debugPrint(
        '👁️ Impression recorded: ${updated.impressionCount} total',
      );
    } catch (e) {
      debugPrint('❌ Failed to record impression: $e');
    }
  }

  /// Record ad error
  Future<void> recordError(String errorCode, String errorMessage, {String? adUnitId}) async {
    try {
      final metadata = await loadMetadata();
      
      final AdMetadata updated;
      if (metadata == null) {
        // Create new metadata for first error
        if (adUnitId == null) {
          debugPrint('⚠️ Cannot record error - no cached metadata and no adUnitId provided');
          return;
        }
        updated = AdMetadata(
          adUnitId: adUnitId,
          loadedAt: DateTime.now(),
          loadAttempts: 1,
          lastErrorCode: errorCode,
          lastErrorMessage: errorMessage,
        );
        debugPrint('💾 Creating metadata for error: $errorCode - $errorMessage');
      } else {
        updated = metadata.copyWith(
          lastErrorCode: errorCode,
          lastErrorMessage: errorMessage,
        );
      }

      await saveMetadata(updated);
      debugPrint('❌ Error recorded: $errorCode - $errorMessage');
    } catch (e) {
      debugPrint('❌ Failed to record error: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getStats() async {
    try {
      final metadata = await loadMetadata();
      if (metadata == null) {
        return {
          'cached': false,
        };
      }

      return {
        'cached': true,
        'adUnitId': metadata.adUnitId,
        'ageMinutes': metadata.ageInMinutes,
        'isStale': metadata.isStale,
        'impressionCount': metadata.impressionCount,
        'loadAttempts': metadata.loadAttempts,
        'hasError': metadata.lastErrorCode != null,
        'lastErrorCode': metadata.lastErrorCode,
        'isPersonalized': metadata.isPersonalized,
      };
    } catch (e) {
      debugPrint('❌ Failed to get cache stats: $e');
      return {'cached': false, 'error': e.toString()};
    }
  }
}

/// Riverpod provider for ad cache service
final adCacheServiceProvider = Provider<AdCacheService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return AdCacheService(storage);
});
