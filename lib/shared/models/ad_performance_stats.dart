/// Performance statistics model for ad dashboard.
///
/// Aggregates metrics from AdPerformanceTracker for display.
class AdPerformanceStats {
  final int totalRequests;
  final int totalImpressions;
  final int totalClicks;
  final int totalCycles;
  final int totalAdsShown;
  final double showRate;
  final double ctr;
  final double avgAdsPerCycle;
  final int avgLoadTimeMs;
  final DateTime lastUpdated;

  // Position-specific data
  final Map<int, PositionStats> positionStats;

  const AdPerformanceStats({
    required this.totalRequests,
    required this.totalImpressions,
    required this.totalClicks,
    required this.totalCycles,
    required this.totalAdsShown,
    required this.showRate,
    required this.ctr,
    required this.avgAdsPerCycle,
    required this.avgLoadTimeMs,
    required this.lastUpdated,
    required this.positionStats,
  });

  factory AdPerformanceStats.empty() {
    return AdPerformanceStats(
      totalRequests: 0,
      totalImpressions: 0,
      totalClicks: 0,
      totalCycles: 0,
      totalAdsShown: 0,
      showRate: 0.0,
      ctr: 0.0,
      avgAdsPerCycle: 0.0,
      avgLoadTimeMs: 0,
      lastUpdated: DateTime.now(),
      positionStats: {},
    );
  }

  /// Format show rate as percentage string
  String get showRateFormatted => '${(showRate * 100).toStringAsFixed(1)}%';

  /// Format CTR as percentage string
  String get ctrFormatted => '${(ctr * 100).toStringAsFixed(2)}%';

  /// Format average ads per cycle
  String get avgAdsPerCycleFormatted => avgAdsPerCycle.toStringAsFixed(1);

  /// Format average load time
  String get avgLoadTimeFormatted =>
      '${(avgLoadTimeMs / 1000).toStringAsFixed(1)}s';

  /// Calculate estimated daily revenue (rough estimate)
  double get estimatedDailyRevenue {
    // Assuming $0.26 eCPM (current rate)
    const ecpm = 0.26;
    return (totalImpressions / 1000) * ecpm;
  }

  /// Format revenue as currency string
  String get revenueFormatted =>
      '\$${estimatedDailyRevenue.toStringAsFixed(2)}';
}

/// Statistics for a specific ad position
class PositionStats {
  final int position;
  final int impressions;
  final int clicks;
  final double ctr;
  final int avgLoadTimeMs;

  const PositionStats({
    required this.position,
    required this.impressions,
    required this.clicks,
    required this.ctr,
    required this.avgLoadTimeMs,
  });

  String get ctrFormatted => '${(ctr * 100).toStringAsFixed(2)}%';
  String get avgLoadTimeFormatted =>
      '${(avgLoadTimeMs / 1000).toStringAsFixed(1)}s';
}
