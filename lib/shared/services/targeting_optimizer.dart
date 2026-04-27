import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Optimizes ad targeting based on user behavior and performance data.
///
/// Dynamically adjusts ad request keywords to improve match rates and eCPM.
/// Tracks user segments and ad interaction patterns.
///
/// **Features:**
/// - Dynamic keyword generation based on user behavior
/// - User segmentation (power user, casual user, etc.)
/// - Performance-based keyword optimization
/// - A/B testing support for keyword combinations
class TargetingOptimizer {
  static const String _userSegmentKey = 'user_ad_segment';
  static const String _interactionHistoryKey = 'ad_interaction_history';

  String _userSegment = 'casual';
  final List<String> _baseKeywords = ['vpn', 'security', 'privacy'];
  final Map<String, int> _keywordPerformance = {};

  /// Get optimized keywords for current user
  List<String> getOptimizedKeywords() {
    final keywords = List<String>.from(_baseKeywords);

    // Add segment-specific keywords
    switch (_userSegment) {
      case 'power_user':
        keywords.addAll(['enterprise', 'business', 'premium']);
        break;
      case 'privacy_focused':
        keywords.addAll(['anonymous', 'encryption', 'secure']);
        break;
      case 'gamer':
        keywords.addAll(['gaming', 'streaming', 'fast']);
        break;
      case 'casual':
      default:
        keywords.addAll(['safe', 'simple', 'reliable']);
        break;
    }

    return keywords;
  }

  /// Update user segment based on behavior
  Future<void> updateUserSegment({
    required int totalConnections,
    required int avgSessionMinutes,
    required int adInteractions,
  }) async {
    String newSegment;

    if (totalConnections > 100 && avgSessionMinutes > 30) {
      newSegment = 'power_user';
    } else if (adInteractions > 20) {
      newSegment = 'ad_engaged';
    } else if (avgSessionMinutes < 10) {
      newSegment = 'casual';
    } else {
      newSegment = 'privacy_focused';
    }

    if (newSegment != _userSegment) {
      _userSegment = newSegment;
      await _persistSegment();
    }
  }

  /// Record keyword performance
  void recordKeywordPerformance({
    required List<String> keywords,
    required bool wasSuccessful,
  }) {
    for (final keyword in keywords) {
      _keywordPerformance[keyword] =
          (_keywordPerformance[keyword] ?? 0) + (wasSuccessful ? 1 : -1);
    }
  }

  /// Get top performing keywords
  List<String> getTopPerformingKeywords({int limit = 5}) {
    final sorted = _keywordPerformance.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// Load persisted data
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userSegment = prefs.getString(_userSegmentKey) ?? 'casual';

      final historyJson = prefs.getString(_interactionHistoryKey);
      if (historyJson != null) {
        final history = jsonDecode(historyJson) as Map<String, dynamic>;
        _keywordPerformance.clear();
        history.forEach((key, value) {
          _keywordPerformance[key] = value as int;
        });
      }
    } catch (e) {
      // Silently fail - start with defaults
    }
  }

  /// Persist current state
  Future<void> _persistSegment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userSegmentKey, _userSegment);
      await prefs.setString(
        _interactionHistoryKey,
        jsonEncode(_keywordPerformance),
      );
    } catch (e) {
      // Silently fail
    }
  }
}

/// Provider for TargetingOptimizer
final targetingOptimizerProvider = Provider<TargetingOptimizer>((ref) {
  final optimizer = TargetingOptimizer();
  optimizer.load(); // Load persisted data asynchronously
  return optimizer;
});
