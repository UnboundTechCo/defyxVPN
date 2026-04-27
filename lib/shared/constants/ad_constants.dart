/// Configuration constants for ad rotation and loading.
///
/// All magic numbers and configuration values are centralized here
/// to make maintenance easier and prevent inconsistencies.
class AdConstants {
  // Prevent instantiation
  AdConstants._();

  // === Rotation Timing ===

  /// Duration each ad is displayed to the user
  static const int adDisplayDurationSeconds = 10;

  /// Total countdown duration for ad cycle
  static const int cycleTimeoutSeconds = 60;

  /// Maximum number of ads shown per disconnect cycle
  static const int maxAdsPerCycle = 5;

  /// When to stop rotation (leave buffer for cleanup)
  static const int rotationStopThresholdSeconds = 55;

  // === Load Timing ===

  /// Minimum expected ad load time (milliseconds)
  static const int minLoadTimeMs = 2000;

  /// Maximum expected ad load time (milliseconds)
  static const int maxLoadTimeMs = 11000;

  /// Average ad load time (used for estimates)
  static const int avgLoadTimeMs = 7000;

  // === Caching ===

  /// How long a preloaded ad remains valid
  static const Duration cacheDuration = Duration(minutes: 10);

  /// Age threshold for ad refresh (in minutes)
  static const int adRefreshAgeMinutes = 15;

  // === Analytics ===

  /// Prefix for session IDs
  static const String sessionIdPrefix = 'ad_session_';

  /// Event name patterns
  static const String eventPrefix = 'ad_';

  // === Error Codes ===

  static const String errorNoInventory = 'NO_INVENTORY';
  static const String errorNetworkTimeout = 'NETWORK_TIMEOUT';
  static const String errorNotReady = 'NOT_READY';
  static const String errorUserReconnected = 'USER_RECONNECTED';
  static const String errorCacheExpired = 'CACHE_EXPIRED';

  // === Debug ===

  /// Enable verbose logging (set false for production)
  static const bool enableDebugLogs = true; // TODO: Set to false in production
}
