import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import '../ads_state.dart';
import '../models/ad_load_result.dart';

/// Callback for fallback to internal ads when primary ad strategy fails
typedef OnFallbackNeeded = void Function();

/// Abstract strategy for loading different types of ads
abstract class AdLoadingStrategy {
  /// Initialize the strategy (called once in initState)
  Future<void> initialize(WidgetRef ref, {OnFallbackNeeded? onFallbackNeeded});
  
  /// Load an ad
  Future<AdLoadResult> loadAd({
    required WidgetRef ref,
  });
  
  /// Build the ad content widget
  Widget buildAdWidget({
    required BuildContext context,
    required AdsState state,
    required double cornerRadius,
  });
  
  /// Handle VPN connection state changes  
  void onConnectionStateChanged({
    required WidgetRef ref,
    required ConnectionStatus previous,
    required ConnectionStatus current,
    required bool hasInitialized,
    required Function() onRefreshNeeded,
  });
  
  /// Check if a new ad should be loaded
  bool shouldLoadNewAd(AdsState state);
  
  /// Cleanup resources
  void dispose();
  
  /// Get the name of this strategy (for debugging)
  String get strategyName;
}
