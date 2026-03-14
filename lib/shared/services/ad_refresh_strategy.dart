import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuration for adaptive ad refresh strategy
class AdRefreshConfig {
  final Duration defaultRefreshAge;
  final Duration prefetchAheadTime;
  final Duration minRefreshInterval;
  final Duration maxRefreshInterval;
  final int highActivityThreshold; // connections per hour
  final int lowActivityThreshold; // connections per hour

  const AdRefreshConfig({
    this.defaultRefreshAge = const Duration(minutes: 15),
    this.prefetchAheadTime = const Duration(minutes: 12),
    this.minRefreshInterval = const Duration(minutes: 10),
    this.maxRefreshInterval = const Duration(minutes: 30),
    this.highActivityThreshold = 10,
    this.lowActivityThreshold = 3,
  });
}

/// User activity level for adaptive refresh
enum UserActivityLevel {
  low, // Infrequent connections
  medium, // Normal usage
  high, // Frequent reconnections
}

/// Adaptive ad refresh strategy
class AdRefreshStrategy {
  final AdRefreshConfig config;
  
  DateTime? _lastAdLoadTime;
  final List<DateTime> _recentConnections = [];
  Timer? _prefetchTimer;
  
  AdRefreshStrategy({
    AdRefreshConfig? config,
  }) : config = config ?? const AdRefreshConfig();

  /// Calculate user activity level based on recent connections
  UserActivityLevel getUserActivityLevel() {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    
    // Count connections in last hour
    _recentConnections.removeWhere((time) => time.isBefore(oneHourAgo));
    final connectionsPerHour = _recentConnections.length;
    
    if (connectionsPerHour >= config.highActivityThreshold) {
      return UserActivityLevel.high;
    } else if (connectionsPerHour <= config.lowActivityThreshold) {
      return UserActivityLevel.low;
    } else {
      return UserActivityLevel.medium;
    }
  }

  /// Get adaptive refresh interval based on user behavior
  Duration getAdaptiveRefreshInterval() {
    final activityLevel = getUserActivityLevel();
    
    switch (activityLevel) {
      case UserActivityLevel.high:
        // Frequent users: shorter refresh (10 min)
        return config.minRefreshInterval;
      
      case UserActivityLevel.low:
        // Infrequent users: longer refresh (30 min)
        return config.maxRefreshInterval;
      
      case UserActivityLevel.medium:
        // Normal users: default refresh (15 min)
        return config.defaultRefreshAge;
    }
  }

  /// Check if ad needs refresh based on adaptive strategy
  bool shouldRefreshAd() {
    if (_lastAdLoadTime == null) return true;
    
    final age = DateTime.now().difference(_lastAdLoadTime!);
    final refreshInterval = getAdaptiveRefreshInterval();
    
    final shouldRefresh = age >= refreshInterval;
    
    if (shouldRefresh) {
      debugPrint(
        '🔄 Ad should refresh: age=${age.inMinutes}m, interval=${refreshInterval.inMinutes}m, activity=${getUserActivityLevel().name}',
      );
    }
    
    return shouldRefresh;
  }

  /// Check if ad is approaching staleness (for prefetch)
  bool shouldPrefetchAd() {
    if (_lastAdLoadTime == null) return false;
    
    final age = DateTime.now().difference(_lastAdLoadTime!);
    final refreshInterval = getAdaptiveRefreshInterval();
    final prefetchTime = refreshInterval - config.prefetchAheadTime;
    
    return age >= prefetchTime && age < refreshInterval;
  }

  /// Record ad load
  void recordAdLoad() {
    _lastAdLoadTime = DateTime.now();
    debugPrint('📝 Ad load recorded at ${_lastAdLoadTime?.toIso8601String()}');
  }

  /// Record connection event for activity tracking
  void recordConnection() {
    _recentConnections.add(DateTime.now());
    
    // Keep only last 20 connections to limit memory
    if (_recentConnections.length > 20) {
      _recentConnections.removeAt(0);
    }
    
    final activityLevel = getUserActivityLevel();
    debugPrint('📊 Connection recorded. Activity level: ${activityLevel.name} (${_recentConnections.length} connections in last hour)');
  }

  /// Schedule background prefetch timer
  void schedulePrefetch(VoidCallback onPrefetch) {
    _cancelPrefetchTimer();
    
    if (_lastAdLoadTime == null) return;
    
    final refreshInterval = getAdaptiveRefreshInterval();
    final prefetchDelay = refreshInterval - config.prefetchAheadTime;
    
    debugPrint('⏰ Scheduling ad prefetch in ${prefetchDelay.inMinutes} minutes');
    
    _prefetchTimer = Timer(prefetchDelay, () {
      debugPrint('🎯 Prefetch timer triggered');
      onPrefetch();
    });
  }

  /// Cancel prefetch timer
  void _cancelPrefetchTimer() {
    _prefetchTimer?.cancel();
    _prefetchTimer = null;
  }

  /// Dispose resources
  void dispose() {
    _cancelPrefetchTimer();
    _recentConnections.clear();
  }

  /// Get strategy status
  Map<String, dynamic> getStatus() {
    final activityLevel = getUserActivityLevel();
    final refreshInterval = getAdaptiveRefreshInterval();
    
    return {
      'lastAdLoadTime': _lastAdLoadTime?.toIso8601String(),
      'adAgeMinutes': _lastAdLoadTime != null 
          ? DateTime.now().difference(_lastAdLoadTime!).inMinutes 
          : 0,
      'recentConnections': _recentConnections.length,
      'activityLevel': activityLevel.name,
      'refreshIntervalMinutes': refreshInterval.inMinutes,
      'shouldRefresh': shouldRefreshAd(),
      'shouldPrefetch': shouldPrefetchAd(),
    };
  }
}

/// Provider for ad refresh strategy
final adRefreshStrategyProvider = Provider<AdRefreshStrategy>((ref) {
  final strategy = AdRefreshStrategy();
  ref.onDispose(() => strategy.dispose());
  return strategy;
});
