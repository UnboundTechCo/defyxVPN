import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks ad performance metrics locally for dashboard display.
///
/// Aggregates:
/// - Requests, impressions, clicks (24h window)
/// - Rotation cycles and ads shown
/// - Position-specific performance
/// - Load times by position
///
/// Calculates KPIs:
/// - Show rate (impressions / requests)
/// - CTR (clicks / impressions)
/// - Average ads per cycle
/// - Average load time
///
/// Data persists across app restarts with automatic 24h window reset.
class AdPerformanceTracker {
  static const String _storageKey = 'ad_performance_metrics';

  // Real-time metrics (24h window)
  int totalRequests24h = 0;
  int totalImpressions24h = 0;
  int totalClicks24h = 0;
  int totalCycles24h = 0;
  int totalAdsShown24h = 0;

  // Position-specific metrics
  final Map<int, int> impressionsByPosition = {};
  final Map<int, int> clicksByPosition = {};
  final Map<int, List<int>> loadTimesByPosition = {};

  // ===== Calculated KPIs =====

  /// Show rate: percentage of requests that resulted in impressions
  double get showRate =>
      totalRequests24h > 0 ? (totalImpressions24h / totalRequests24h) : 0.0;

  /// Click-through rate: percentage of impressions that were clicked
  double get ctr =>
      totalImpressions24h > 0 ? (totalClicks24h / totalImpressions24h) : 0.0;

  /// Average number of ads shown per rotation cycle
  double get avgAdsPerCycle =>
      totalCycles24h > 0 ? (totalAdsShown24h / totalCycles24h) : 0.0;

  /// Average ad load time across all positions (milliseconds)
  int get avgLoadTime {
    final allLoadTimes = loadTimesByPosition.values.expand((e) => e).toList();
    if (allLoadTimes.isEmpty) return 0;
    return (allLoadTimes.reduce((a, b) => a + b) / allLoadTimes.length).round();
  }

  /// Get load time for specific position
  int getAvgLoadTimeForPosition(int position) {
    final times = loadTimesByPosition[position];
    if (times == null || times.isEmpty) return 0;
    return (times.reduce((a, b) => a + b) / times.length).round();
  }

  /// Get impression count for specific position
  int getImpressionsForPosition(int position) {
    return impressionsByPosition[position] ?? 0;
  }

  /// Get click count for specific position
  int getClicksForPosition(int position) {
    return clicksByPosition[position] ?? 0;
  }

  /// Get CTR for specific position
  double getCtrForPosition(int position) {
    final impressions = getImpressionsForPosition(position);
    final clicks = getClicksForPosition(position);
    return impressions > 0 ? (clicks / impressions) : 0.0;
  }

  // ===== Recording Methods =====

  /// Record an ad request
  void recordRequest() {
    totalRequests24h++;
    _persist();
  }

  /// Record an ad impression at specific position
  void recordImpression(int position) {
    totalImpressions24h++;
    impressionsByPosition[position] =
        (impressionsByPosition[position] ?? 0) + 1;
    _persist();
  }

  /// Record an ad click at specific position
  void recordClick(int position) {
    totalClicks24h++;
    clicksByPosition[position] = (clicksByPosition[position] ?? 0) + 1;
    _persist();
  }

  /// Record a completed rotation cycle
  void recordCycle(int adsShown) {
    totalCycles24h++;
    totalAdsShown24h += adsShown;
    _persist();
  }

  /// Record ad load time for specific position
  void recordLoadTime(int position, int durationMs) {
    if (!loadTimesByPosition.containsKey(position)) {
      loadTimesByPosition[position] = [];
    }
    loadTimesByPosition[position]!.add(durationMs);
    _persist();
  }

  // ===== Persistence =====

  /// Reset all metrics (called after 24h)
  void reset24hWindow() {
    totalRequests24h = 0;
    totalImpressions24h = 0;
    totalClicks24h = 0;
    totalCycles24h = 0;
    totalAdsShown24h = 0;
    impressionsByPosition.clear();
    clicksByPosition.clear();
    loadTimesByPosition.clear();
    _persist();
  }

  /// Persist metrics to SharedPreferences
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'total_requests_24h': totalRequests24h,
        'total_impressions_24h': totalImpressions24h,
        'total_clicks_24h': totalClicks24h,
        'total_cycles_24h': totalCycles24h,
        'total_ads_shown_24h': totalAdsShown24h,
        'last_reset': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      // Silently fail - metrics are not critical
    }
  }

  /// Load persisted metrics from SharedPreferences
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_storageKey);
      if (dataStr != null) {
        final data = jsonDecode(dataStr);
        totalRequests24h = data['total_requests_24h'] ?? 0;
        totalImpressions24h = data['total_impressions_24h'] ?? 0;
        totalClicks24h = data['total_clicks_24h'] ?? 0;
        totalCycles24h = data['total_cycles_24h'] ?? 0;
        totalAdsShown24h = data['total_ads_shown_24h'] ?? 0;

        // Check if 24h passed since last reset
        final lastReset = data['last_reset'] as int?;
        if (lastReset != null) {
          final elapsed = DateTime.now().millisecondsSinceEpoch - lastReset;
          if (elapsed > 24 * 60 * 60 * 1000) {
            // More than 24h passed - reset window
            reset24hWindow();
          }
        }
      }
    } catch (e) {
      // Silently fail - start fresh if can't load
    }
  }
}

/// Provider for AdPerformanceTracker
final adPerformanceTrackerProvider = Provider<AdPerformanceTracker>((ref) {
  final tracker = AdPerformanceTracker();
  tracker.load(); // Load persisted data asynchronously
  return tracker;
});
