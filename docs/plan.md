## Plan: Complete Ad Revenue Optimization System

**TL;DR:** Implement ad rotation with parallel loading, comprehensive analytics, mediation, enhanced targeting, and UX optimizations to increase revenue from $0.135/day to $1.40+/day (+900%+).

**Current Performance (April 27, 2026):**
- 538 impressions/day (30% show rate)
- $0.135/day revenue
- $0.26 eCPM
- 4,500 requests/day
- 7-11 second ad load time (MAJOR BOTTLENECK)

**Target Performance (3 weeks):**
- 3,150+ impressions/day (50% show rate × 5 ads)
- $0.82/day revenue (+486%)
- $0.26 eCPM (current, no mediation)
- 10-second ad display + 7s load (parallel after first ad)
- 55% match rate (from enhanced targeting)

---

## **Complete Implementation Architecture**

### **Core Strategy: Parallel Ad Loading During Display**

**Key Insight:** While showing Ad N (10 seconds), load Ad N+1 in parallel (takes 7-11 seconds)

```
Timeline (60 seconds total):

0s:  User disconnects (Real IP)
0s:  → Load Ad #1 (7s)
7s:  → Show Ad #1 (10s) + START LOADING Ad #2 in parallel
17s: → Show Ad #2 (10s) + START LOADING Ad #3 in parallel  
27s: → Show Ad #3 (10s) + START LOADING Ad #4 in parallel
37s: → Show Ad #4 (10s) + START LOADING Ad #5 in parallel
47s: → Show Ad #5 (10s) 
57s: → Cycle ends (user can reconnect)

Result: 5 ads shown in 60 seconds
        All with same Real IP (no fraud risk)
```

**Critical Rules:**
✅ Load ads ONLY while disconnected (real IP consistent)
✅ Load next ad DURING current ad display (parallel)
✅ All ads in one cycle use SAME IP
✅ Stop rotation at 55s mark (allow cleanup)

---

## **Phase 1: Ad Rotation System with Parallel Loading** (Week 1, Days 1-4)

**Objective:** Show 5 ads per 60-second window with parallel loading

### **1.1 Create AdRotationManager Service** (*Day 1-2*)

**File:** `lib/shared/services/ad_rotation_manager.dart` (250 lines)

**Responsibilities:**
- Track current position (1-5)
- Coordinate parallel loading
- Manage timing: Show current + Load next
- Handle load failures gracefully
- Stop rotation on reconnect
- Comprehensive analytics

**Key Methods:**
```dart
class AdRotationManager {
  int currentPosition = 1;
  int maxAdsPerCycle = 5;
  bool isRotating = false;
  DateTime? cycleStartTime;
  String? sessionId;
  
  NativeAd? currentAd;
  NativeAd? nextAd; // Preloaded
  bool isLoadingNext = false;
  
  // Start rotation cycle
  Future<void> startRotationCycle(Ref ref) {
    currentPosition = 1;
    sessionId = generateSessionId();
    cycleStartTime = DateTime.now();
    isRotating = true;
    
    // Load first ad
    await _loadAndShowAd(position: 1, ref: ref);
  }
  
  // Load and show ad at position
  Future<void> _loadAndShowAd({required int position, required Ref ref}) async {
    // Check if next ad was preloaded
    if (nextAd != null) {
      currentAd = nextAd;
      nextAd = null;
      _showAdImmediately(position);
    } else {
      // Load on demand (first ad or preload failed)
      currentAd = await _loadAdAtPosition(position, ref);
      _showAd(position);
    }
    
    // Start preloading next ad (parallel)
    if (position < maxAdsPerCycle) {
      _startPreloadingNext(position + 1, ref);
    }
    
    // Schedule next ad display
    if (position < maxAdsPerCycle) {
      Future.delayed(Duration(seconds: 10), () {
        if (isRotating) {
          _loadAndShowAd(position: position + 1, ref: ref);
        }
      });
    }
  }
  
  // Preload next ad in background
  Future<void> _startPreloadingNext(int nextPosition, Ref ref) async {
    if (isLoadingNext) return;
    
    isLoadingNext = true;
    analytics.logAdPreloadStarted(position: nextPosition);
    
    final loadStartTime = DateTime.now();
    nextAd = await _loadAdAtPosition(nextPosition, ref);
    final loadDuration = DateTime.now().difference(loadStartTime);
    
    if (nextAd != null) {
      analytics.logAdPreloadSuccess(
        position: nextPosition,
        durationMs: loadDuration.inMilliseconds,
      );
    } else {
      analytics.logAdPreloadFailure(position: nextPosition);
    }
    
    isLoadingNext = false;
  }
  
  // Stop rotation (user reconnected)
  void stopRotation(Ref ref) {
    isRotating = false;
    currentAd?.dispose();
    nextAd?.dispose();
    currentAd = null;
    nextAd = null;
    
    analytics.logRotationCycleStopped(
      adsShown: currentPosition,
      durationSeconds: DateTime.now().difference(cycleStartTime!).inSeconds,
    );
  }
}
```

### **1.2 Update GoogleAdStrategy for Rotation** (*Day 2-3*)

**File:** `lib/modules/main/presentation/widgets/ads/strategy/google_ad_strategy.dart`

**Changes:**
- Add `position` parameter to `loadAd()`
- Track position in analytics
- Support parallel loading
- Return `NativeAd` instance for caching

**Modified Method:**
```dart
Future<NativeAd?> loadAdAtPosition({
  required int position,
  required Ref ref,
}) async {
  final sessionId = ref.read(rotationManagerProvider).sessionId;
  
  // Analytics: Track request
  analytics.logAdPositionLoadStarted(
    position: position,
    sessionId: sessionId,
  );
  
  final loadStartTime = DateTime.now();
  
  // Load ad with position tracking
  final ad = NativeAd(
    adUnitId: adUnitId,
    listener: NativeAdListener(
      onAdLoaded: (ad) {
        final loadDuration = DateTime.now().difference(loadStartTime);
        
        analytics.logAdPositionLoadSuccess(
          position: position,
          sessionId: sessionId,
          durationMs: loadDuration.inMilliseconds,
        );
      },
      onAdFailedToLoad: (ad, error) {
        analytics.logAdPositionLoadFailure(
          position: position,
          sessionId: sessionId,
          errorCode: error.code.toString(),
          errorMessage: error.message,
        );
      },
      onAdImpression: (ad) {
        analytics.logAdPositionImpression(
          position: position,
          sessionId: sessionId,
        );
      },
      onAdClicked: (ad) {
        analytics.logAdPositionClicked(
          position: position,
          sessionId: sessionId,
        );
      },
    ),
    request: AdRequest(
      keywords: [...],
      extras: {
        'position': position.toString(),
        'session_id': sessionId,
      },
    ),
    nativeTemplateStyle: templateStyle,
  );
  
  ad.load();
  return ad;
}
```

### **1.3 Update AdsState for Rotation** (*Day 3*)

**File:** `lib/modules/main/presentation/widgets/ads/ads_state.dart`

**New Fields:**
```dart
class AdsState {
  // Rotation fields
  final int currentAdPosition; // 1-5
  final int adsShownThisCycle;
  final bool isRotating;
  final String? sessionId;
  final DateTime? cycleStartTime;
  
  // Parallel loading
  final bool nextAdPreloading;
  final int? nextAdPosition;
  final DateTime? nextAdLoadStartTime;
  
  // Timing
  final DateTime? currentAdStartTime;
  final int remainingDisplayTime; // seconds left for current ad
  
  // Existing fields...
  final bool nativeAdIsLoaded;
  final int countdown;
  final bool showCountdown;
  // ...
}
```

### **1.4 Integration with Countdown Timer** (*Day 4*)

**File:** `lib/modules/main/presentation/widgets/ads/ads_state.dart`

**Modified Timer Logic:**
```dart
void startCountdownTimer() {
  _countdownTimer?.cancel();
  
  // Start rotation manager
  final rotationManager = ref.read(rotationManagerProvider);
  rotationManager.startRotationCycle(ref);
  
  state = state.copyWith(
    countdown: countdownDuration,
    showCountdown: true,
    isRotating: true,
    cycleStartTime: DateTime.now(),
  );
  
  _startCountdownFromValue(countdownDuration);
}

void _startCountdownFromValue(int startValue) {
  _countdownTimer?.cancel();
  
  _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (state.countdown > 0) {
      final newCount = state.countdown - 1;
      state = state.copyWith(countdown: newCount);
      
      // Stop rotation at 55s (allow cleanup)
      if (newCount <= 5 && state.isRotating) {
        final rotationManager = ref.read(rotationManagerProvider);
        rotationManager.stopRotation(ref);
      }
    } else {
      // Cleanup
      state = state.copyWith(
        showCountdown: false,
        isRotating: false,
        currentAdPosition: 0,
      );
      timer.cancel();
    }
  });
}
```


---

## **Phase 2: Comprehensive Firebase Analytics** (Week 1, Days 1-3, parallel with Phase 1)

**Objective:** Track every ad event to measure rotation performance and identify bottlenecks

### **2.1 Create AdAnalyticsService** (*Day 1-2*)

**File:** `lib/shared/services/ad_analytics_service.dart` (200 lines)

**All Analytics Events:**

```dart
class AdAnalyticsService {
  final FirebaseAnalyticsService _firebase = FirebaseAnalyticsService();
  
  // ===== Rotation Lifecycle =====
  
  Future<void> logRotationCycleStarted({
    required String sessionId,
  }) async {
    await _firebase.logEvent(
      name: 'ad_rotation_cycle_started',
      parameters: {
        'session_id': sessionId,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
  }
  
  Future<void> logRotationCycleCompleted({
    required String sessionId,
    required int totalAdsShown,
    required int totalClicks,
    required int durationSeconds,
  }) async {
    await _firebase.logEvent(
      name: 'ad_rotation_cycle_completed',
      parameters: {
        'session_id': sessionId,
        'total_ads_shown': totalAdsShown.toString(),
        'total_clicks': totalClicks.toString(),
        'duration_seconds': durationSeconds.toString(),
      },
    );
  }
  
  Future<void> logRotationCycleStopped({
    required String sessionId,
    required int adsShown,
    required String reason, // 'user_reconnected', 'timeout', 'error'
  }) async {
    await _firebase.logEvent(
      name: 'ad_rotation_cycle_stopped',
      parameters: {
        'session_id': sessionId,
        'ads_shown': adsShown.toString(),
        'stop_reason': reason,
      },
    );
  }
  
  // ===== Position-Specific Events =====
  
  Future<void> logAdPositionLoadStarted({
    required int position,
    required String sessionId,
  }) async {
    await _firebase.logEvent(
      name: 'ad_position_load_started',
      parameters: {
        'position': position.toString(),
        'session_id': sessionId,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
  }
  
  Future<void> logAdPositionLoadSuccess({
    required int position,
    required String sessionId,
    required int durationMs,
  }) async {
    await _firebase.logEvent(
      name: 'ad_position_load_success',
      parameters: {
        'position': position.toString(),
        'session_id': sessionId,
        'load_duration_ms': durationMs.toString(),
      },
    );
  }
  
  Future<void> logAdPositionLoadFailure({
    required int position,
    required String sessionId,
    required String errorCode,
    required String errorMessage,
  }) async {
    await _firebase.logEvent(
      name: 'ad_position_load_failure',
      parameters: {
        'position': position.toString(),
        'session_id': sessionId,
        'error_code': errorCode,
        'error_message': errorMessage,
      },
    );
  }
  
  Future<void> logAdPositionImpression({
    required int position,
    required String sessionId,
  }) async {
    await _firebase.logEvent(
      name: 'ad_position_impression',
      parameters: {
        'position': position.toString(),
        'session_id': sessionId,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
  }
  
  Future<void> logAdPositionClicked({
    required int position,
    required String sessionId,
  }) async {
    await _firebase.logEvent(
      name: 'ad_position_clicked',
      parameters: {
        'position': position.toString(),
        'session_id': sessionId,
      },
    );
  }
  
  // ===== Parallel Loading Events =====
  
  Future<void> logAdPreloadStarted({
    required int position,
    required String sessionId,
  }) async {
    await _firebase.logEvent(
      name: 'ad_preload_started',
      parameters: {
        'next_position': position.toString(),
        'session_id': sessionId,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
  }
  
  Future<void> logAdPreloadSuccess({
    required int position,
    required String sessionId,
    required int durationMs,
  }) async {
    await _firebase.logEvent(
      name: 'ad_preload_success',
      parameters: {
        'position': position.toString(),
        'session_id': sessionId,
        'duration_ms': durationMs.toString(),
      },
    );
  }
  
  Future<void> logAdPreloadFailure({
    required int position,
    required String sessionId,
    required String reason,
  }) async {
    await _firebase.logEvent(
      name: 'ad_preload_failure',
      parameters: {
        'position': position.toString(),
        'session_id': sessionId,
        'failure_reason': reason,
      },
    );
  }
  
  Future<void> logAdCacheHit({
    required int position,
    required String sessionId,
  }) async {
    await _firebase.logEvent(
      name: 'ad_cache_hit',
      parameters: {
        'position': position.toString(),
        'session_id': sessionId,
      },
    );
  }
  
  Future<void> logAdCacheMiss({
    required int position,
    required String sessionId,
    required String reason, // 'preload_failed', 'preload_timeout', 'not_started'
  }) async {
    await _firebase.logEvent(
      name: 'ad_cache_miss',
      parameters: {
        'position': position.toString(),
        'session_id': sessionId,
        'miss_reason': reason,
      },
    );
  }
  
  // ===== Performance Metrics =====
  
  Future<void> logShowRateMetrics({
    required int periodHours,
    required int totalRequests,
    required int totalImpressions,
  }) async {
    final showRate = (totalImpressions / totalRequests * 100).round();
    
    await _firebase.logEvent(
      name: 'ad_show_rate_metrics',
      parameters: {
        'period_hours': periodHours.toString(),
        'show_rate_percent': showRate.toString(),
        'total_requests': totalRequests.toString(),
        'total_impressions': totalImpressions.toString(),
      },
    );
  }
  
  Future<void> logRotationPerformance({
    required int periodHours,
    required double avgAdsPerCycle,
    required double avgCycleDuration,
    required int totalCycles,
  }) async {
    await _firebase.logEvent(
      name: 'ad_rotation_performance',
      parameters: {
        'period_hours': periodHours.toString(),
        'avg_ads_per_cycle': avgAdsPerCycle.toStringAsFixed(2),
        'avg_cycle_duration_seconds': avgCycleDuration.toStringAsFixed(1),
        'total_cycles': totalCycles.toString(),
      },
    );
  }
  
  // ===== User Properties =====
  
  Future<void> setUserAdConsent(String consentType) async {
    await _firebase.setUserProperty(
      name: 'ad_consent_type',
      value: consentType, // 'personalized' or 'non_personalized'
    );
  }
  
  Future<void> incrementUserAdViews() async {
    // Get current count, increment, set
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt('total_ad_views_lifetime') ?? 0;
    await prefs.setInt('total_ad_views_lifetime', currentCount + 1);
    
    await _firebase.setUserProperty(
      name: 'total_ad_views_lifetime',
      value: (currentCount + 1).toString(),
    );
  }
}
```

### **2.2 Create AdPerformanceTracker** (*Day 2-3*)

**File:** `lib/shared/services/ad_performance_tracker.dart` (120 lines)

**Responsibilities:**
- Aggregate metrics from analytics
- Calculate KPIs (show rate, fill rate, CTR)
- Persist to SharedPreferences
- Export data for dashboard

```dart
class AdPerformanceTracker {
  static const String _storageKey = 'ad_performance_metrics';
  
  // Real-time metrics
  int totalRequests24h = 0;
  int totalImpressions24h = 0;
  int totalClicks24h = 0;
  int totalCycles24h = 0;
  int totalAdsShown24h = 0;
  
  Map<int, int> impressionsByPosition = {}; // position -> count
  Map<int, int> clicksByPosition = {}; // position -> count
  Map<int, List<int>> loadTimesByPosition = {}; // position -> [durations]
  
  // Calculated KPIs
  double get showRate => 
    totalRequests24h > 0 ? (totalImpressions24h / totalRequests24h) : 0.0;
  
  double get ctr => 
    totalImpressions24h > 0 ? (totalClicks24h / totalImpressions24h) : 0.0;
  
  double get avgAdsPerCycle =>
    totalCycles24h > 0 ? (totalAdsShown24h / totalCycles24h) : 0.0;
  
  int get avgLoadTime {
    final allLoadTimes = loadTimesByPosition.values.expand((e) => e).toList();
    if (allLoadTimes.isEmpty) return 0;
    return (allLoadTimes.reduce((a, b) => a + b) / allLoadTimes.length).round();
  }
  
  // Track request
  void recordRequest() {
    totalRequests24h++;
    _persist();
  }
  
  // Track impression
  void recordImpression(int position) {
    totalImpressions24h++;
    impressionsByPosition[position] = (impressionsByPosition[position] ?? 0) + 1;
    _persist();
  }
  
  // Track click
  void recordClick(int position) {
    totalClicks24h++;
    clicksByPosition[position] = (clicksByPosition[position] ?? 0) + 1;
    _persist();
  }
  
  // Track cycle
  void recordCycle(int adsShown) {
    totalCycles24h++;
    totalAdsShown24h += adsShown;
    _persist();
  }
  
  // Track load time
  void recordLoadTime(int position, int durationMs) {
    if (!loadTimesByPosition.containsKey(position)) {
      loadTimesByPosition[position] = [];
    }
    loadTimesByPosition[position]!.add(durationMs);
    _persist();
  }
  
  // Reset 24h window
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
  
  // Persistence
  Future<void> _persist() async {
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
  }
  
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final dataStr = prefs.getString(_storageKey);
    if (dataStr != null) {
      final data = jsonDecode(dataStr);
      totalRequests24h = data['total_requests_24h'] ?? 0;
      totalImpressions24h = data['total_impressions_24h'] ?? 0;
      totalClicks24h = data['total_clicks_24h'] ?? 0;
      totalCycles24h = data['total_cycles_24h'] ?? 0;
      totalAdsShown24h = data['total_ads_shown_24h'] ?? 0;
      
      // Check if 24h passed
      final lastReset = data['last_reset'] as int?;
      if (lastReset != null) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - lastReset;
        if (elapsed > 24 * 60 * 60 * 1000) {
          reset24hWindow();
        }
      }
    }
  }
}
```

**Files to create:**
- NEW: `lib/shared/services/ad_analytics_service.dart` (200 lines)
- NEW: `lib/shared/services/ad_performance_tracker.dart` (120 lines)

**Files to modify:**
- `lib/modules/main/presentation/widgets/ads/strategy/google_ad_strategy.dart` - Integrate analytics calls
- `lib/shared/services/firebase_analytics_service.dart` - Add helper methods (if needed)

---

## **Phase 3: Ad Mediation** (Week 2, Days 1-5)

**Objective:** Add Facebook Audience Network + AppLovin MAX for higher eCPM and faster loading

### **3.1 Add Dependencies** (*Day 1*)

**File:** `pubspec.yaml`

```yaml
dependencies:
  google_mobile_ads: ^5.1.0  # Existing
  facebook_audience_network: ^1.3.0  # NEW
  applovin_max: ^3.9.0  # NEW
```

### **3.2 Configure Ad Network IDs** (*Day 1*)

**File:** `.env`

```env
# Existing
ANDROID_AD_UNIT_ID=ca-app-pub-xxx
IOS_AD_UNIT_ID=ca-app-pub-yyy

# NEW: Facebook Audience Network
FACEBOOK_ANDROID_PLACEMENT_ID=YOUR_ANDROID_PLACEMENT_ID
FACEBOOK_IOS_PLACEMENT_ID=YOUR_IOS_PLACEMENT_ID

# NEW: AppLovin MAX
APPLOVIN_ANDROID_AD_UNIT_ID=YOUR_ANDROID_AD_UNIT
APPLOVIN_IOS_AD_UNIT_ID=YOUR_IOS_AD_UNIT
APPLOVIN_SDK_KEY=YOUR_SDK_KEY
```

### **3.3 Create FacebookAdAdapter** (*Day 2*)

**File:** `lib/shared/adapters/facebook_ad_adapter.dart` (120 lines)

```dart
class FacebookAdAdapter {
  static String get placementId {
    if (Platform.isAndroid) {
      return dotenv.env['FACEBOOK_ANDROID_PLACEMENT_ID'] ?? '';
    } else if (Platform.isIOS) {
      return dotenv.env['FACEBOOK_IOS_PLACEMENT_ID'] ?? '';
    }
    return '';
  }
  
  Future<FacebookNativeAd?> loadNativeAd({
    required int position,
    required Function(FacebookNativeAd) onLoaded,
    required Function(int errorCode, String errorMessage) onError,
    required Function() onImpression,
    required Function() onClicked,
  }) async {
    final ad = FacebookNativeAd(
      placementId: placementId,
      adType: NativeAdType.NATIVE_AD,
      listener: (result, value) {
        switch (result) {
          case NativeAdResult.LOADED:
            onLoaded(ad);
            break;
          case NativeAdResult.ERROR:
            onError(0, value['error_message'] ?? 'Unknown error');
            break;
          case NativeAdResult.IMPRESSION:
            onImpression();
            break;
          case NativeAdResult.CLICKED:
            onClicked();
            break;
          default:
            break;
        }
      },
    );
    
    await ad.loadAd();
    return ad;
  }
  
  void disposeAd(FacebookNativeAd? ad) {
    ad?.dispose();
  }
}
```

### **3.4 Create AppLovinAdAdapter** (*Day 2-3*)

**File:** `lib/shared/adapters/applovin_ad_adapter.dart` (120 lines)

```dart
class AppLovinAdAdapter {
  static String get adUnitId {
    if (Platform.isAndroid) {
      return dotenv.env['APPLOVIN_ANDROID_AD_UNIT_ID'] ?? '';
    } else if (Platform.isIOS) {
      return dotenv.env['APPLOVIN_IOS_AD_UNIT_ID'] ?? '';
    }
    return '';
  }
  
  static Future<void> initialize() async {
    final sdkKey = dotenv.env['APPLOVIN_SDK_KEY'] ?? '';
    await AppLovinMAX.initialize(sdkKey);
  }
  
  Future<void> loadNativeAd({
    required int position,
    required Function() onLoaded,
    required Function(int errorCode, String errorMessage) onError,
    required Function() onImpression,
    required Function() onClicked,
  }) async {
    AppLovinMAX.setNativeAdListener(NativeAdListener(
      onAdLoaded: (ad) => onLoaded(),
      onAdLoadFailed: (adUnitId, error) => onError(
        error.code,
        error.message,
      ),
      onAdDisplayed: (ad) => onImpression(),
      onAdClicked: (ad) => onClicked(),
    ));
    
    await AppLovinMAX.loadNativeAd(adUnitId);
  }
}
```

### **3.5 Create AdMediationManager** (*Day 3-4*)

**File:** `lib/shared/services/ad_mediation_manager.dart` (180 lines)

**Responsibilities:**
- Coordinate multiple ad networks
- Waterfall logic: AdMob → Facebook → AppLovin
- Track which network served
- Auto-optimize order based on eCPM

```dart
class AdMediationManager {
  final GoogleAdStrategy _admob;
  final FacebookAdAdapter _facebook;
  final AppLovinAdAdapter _applovin;
  final AdAnalyticsService _analytics;
  
  // Network priority (dynamic based on performance)
  List<String> networkPriority = ['admob', 'facebook', 'applovin'];
  
  // Performance tracking per network
  Map<String, NetworkPerformance> performance = {};
  
  Future<MediationAdResult> loadAdAtPosition({
    required int position,
    required Ref ref,
  }) async {
    // Try networks in priority order
    for (final network in networkPriority) {
      try {
        switch (network) {
          case 'admob':
            final ad = await _admob.loadAdAtPosition(
              position: position,
              ref: ref,
            );
            if (ad != null) {
              _analytics.logAdServedByNetwork(
                network: 'admob',
                position: position,
              );
              return MediationAdResult.success(
                ad: ad,
                network: 'admob',
              );
            }
            break;
            
          case 'facebook':
            final ad = await _facebook.loadNativeAd(
              position: position,
              onLoaded: (ad) {},
              onError: (code, msg) {},
              onImpression: () {},
              onClicked: () {},
            );
            if (ad != null) {
              _analytics.logAdServedByNetwork(
                network: 'facebook',
                position: position,
              );
              return MediationAdResult.success(
                ad: ad,
                network: 'facebook',
              );
            }
            break;
            
          case 'applovin':
            await _applovin.loadNativeAd(
              position: position,
              onLoaded: () {
                _analytics.logAdServedByNetwork(
                  network: 'applovin',
                  position: position,
                );
              },
              onError: (code, msg) {},
              onImpression: () {},
              onClicked: () {},
            );
            return MediationAdResult.success(
              ad: null, // AppLovin handles display internally
              network: 'applovin',
            );
        }
      } catch (e) {
        _analytics.logNetworkLoadFailure(
          network: network,
          position: position,
          error: e.toString(),
        );
        continue;
      }
    }
    
    return MediationAdResult.failure(
      errorCode: 'ALL_NETWORKS_FAILED',
      errorMessage: 'No network could serve an ad',
    );
  }
  
  // Optimize network order based on eCPM
  void optimizeNetworkPriority() {
    // Calculate average eCPM per network
    final networkEcpm = <String, double>{};
    
    for (final entry in performance.entries) {
      final perf = entry.value;
      if (perf.impressions > 0) {
        networkEcpm[entry.key] = perf.revenue / perf.impressions * 1000;
      }
    }
    
    // Sort by eCPM descending
    networkPriority.sort((a, b) {
      final ecpmA = networkEcpm[a] ?? 0.0;
      final ecpmB = networkEcpm[b] ?? 0.0;
      return ecpmB.compareTo(ecpmA);
    });
    
    debugPrint('📊 Network priority optimized: $networkPriority');
  }
}

class NetworkPerformance {
  int requests = 0;
  int impressions = 0;
  int clicks = 0;
  double revenue = 0.0;
  int totalLoadTimeMs = 0;
  
  double get fillRate => requests > 0 ? impressions / requests : 0.0;
  double get ctr => impressions > 0 ? clicks / impressions : 0.0;
  double get ecpm => impressions > 0 ? (revenue / impressions * 1000) : 0.0;
  double get avgLoadTimeMs => impressions > 0 ? totalLoadTimeMs / impressions : 0.0;
}
```

### **3.6 Integrate Mediation into GoogleAdStrategy** (*Day 4-5*)

**File:** `lib/modules/main/presentation/widgets/ads/strategy/google_ad_strategy.dart`

**Changes:**
- Replace direct AdMob calls with MediationManager
- Track serving network
- Update analytics

```dart
class GoogleAdStrategy implements AdLoadingStrategy {
  final AdMediationManager _mediationManager;
  
  @override
  Future<NativeAd?> loadAdAtPosition({
    required int position,
    required Ref ref,
  }) async {
    // Use mediation instead of direct AdMob
    final result = await _mediationManager.loadAdAtPosition(
      position: position,
      ref: ref,
    );
    
    if (result.success) {
      debugPrint('✅ Ad loaded via ${result.network}');
      return result.ad as NativeAd?;
    } else {
      debugPrint('❌ All networks failed for position $position');
      return null;
    }
  }
}
```


---

## **Phase 3: Enhanced Targeting & UX Optimization** (Week 2, Days 1-3)

**Objective:** Increase match rate from 41% to 60% + reduce user abandonment

### **4.1 Dynamic Keyword Selection** (*Day 1*)

**File:** `lib/shared/services/targeting_optimizer.dart` (150 lines)

**Strategy:** Adapt keywords based on user behavior

```dart
class TargetingOptimizer {
  // User segmentation
  enum UserSegment {
    casual,      // < 5 connections/day
    regular,     // 5-15 connections/day
    powerUser,   // > 15 connections/day
  }
  
  Future<List<String>> getOptimizedKeywords(Ref ref) async {
    final segment = await _getUserSegment();
    final timeOfDay = DateTime.now().hour;
    final deviceType = await _getDeviceType();
    
    List<String> keywords = [];
    
    // Base VPN keywords (always included)
    keywords.addAll([
      'vpn', 'vpn service', 'secure vpn', 'privacy vpn',
      'online privacy', 'internet security',
    ]);
    
    // Segment-specific keywords
    switch (segment) {
      case UserSegment.casual:
        keywords.addAll([
          'free vpn', 'vpn trial', 'easy vpn',
          'vpn for beginners', 'simple vpn',
        ]);
        break;
      case UserSegment.regular:
        keywords.addAll([
          'reliable vpn', 'fast vpn', 'stable vpn',
          'vpn subscription', 'premium vpn',
        ]);
        break;
      case UserSegment.powerUser:
        keywords.addAll([
          'business vpn', 'enterprise vpn', 'professional vpn',
          'dedicated ip', 'vpn for streaming', 'gaming vpn',
        ]);
        break;
    }
    
    // Time-based keywords
    if (timeOfDay >= 9 && timeOfDay <= 17) {
      // Business hours
      keywords.addAll([
        'work vpn', 'remote work', 'secure connection',
        'office vpn', 'business security',
      ]);
    } else {
      // Evening/night
      keywords.addAll([
        'streaming vpn', 'netflix vpn', 'entertainment vpn',
        'unblock content', 'access geo-restricted',
      ]);
    }
    
    // Device-specific
    if (deviceType == DeviceType.premium) {
      // High-end devices → premium targeting
      keywords.addAll([
        'premium service', 'high-speed vpn', 'unlimited vpn',
      ]);
    }
    
    return keywords.toSet().toList(); // Remove duplicates
  }
  
  Future<UserSegment> _getUserSegment() async {
    final prefs = await SharedPreferences.getInstance();
    final connectionsLast7Days = prefs.getInt('connections_last_7_days') ?? 0;
    final avgPerDay = connectionsLast7Days / 7;
    
    if (avgPerDay < 5) return UserSegment.casual;
    if (avgPerDay < 15) return UserSegment.regular;
    return UserSegment.powerUser;
  }
  
  Future<DeviceType> _getDeviceType() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo; // or iosInfo
    // Check model, RAM, etc.
    return DeviceType.regular; // Simplified
  }
}

enum DeviceType { budget, regular, premium }
```

### **3.2 UX Optimization: Reconnect Delay** (*Day 2*)

**File:** `lib/modules/main/presentation/widgets/ads/strategy/google_ad_strategy.dart`

**Changes:** Add dynamic keywords to ad request

```dart
Future<NativeAd?> loadAdAtPosition({
  required int position,
  required Ref ref,
}) async {
  // ... existing code ...
  
  final ad = NativeAd(
    adUnitId: adUnitId,
    listener: /* ... */,
    request: AdRequest(
      keywords: await _targetingOptimizer.getOptimizedKeywords(ref),
      contentUrl: 'https://defyxvpn.com',
      nonPersonalizedAds: !canUsePersonalizedAds,
      extras: {
        'app_category': 'utilities',
        'app_subcategory': 'vpn',
        'placement': 'main_screen_disconnected',
        'position': position.toString(),
        ...adReadinessExtras,
      },
    ),
    nativeTemplateStyle: templateStyle,
  );
  
  ad.load();
  return ad;
}
```

**Note:** Floor pricing can be added later if needed to filter low-paying ads.

### **3.3 Connection Usage Tracking** (*Day 3*)

**File:** `lib/modules/main/presentation/screens/main_screen.dart`

**Changes:** Add 3-second delay before reconnect button enables

```dart
class _MainScreenState extends ConsumerState<MainScreen> {
  bool _isReconnectDisabled = false;
  
  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    
    // Listen for disconnects
    ref.listen(connectionStateProvider, (previous, next) {
      if (next.status == ConnectionStatus.disconnected &&
          previous?.status == ConnectionStatus.connected) {
        _onDisconnected();
      }
    });
    
    return /* ... */;
  }
  
  void _onDisconnected() {
    // Disable reconnect for 3 seconds
    setState(() {
      _isReconnectDisabled = true;
    });
    
    // Show loading message
    _showReconnectPreparingMessage();
    
    // Re-enable after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isReconnectDisabled = false;
        });
      }
    });
    
    // Analytics
    _analytics.logEvent(
      name: 'reconnect_delay_started',
      parameters: {'duration_seconds': '3'},
    );
  }
  
  void _showReconnectPreparingMessage() {
    // Show subtle loading indicator
    // "Preparing connection..." or progress bar
  }
  
  Widget _buildConnectButton() {
    return ElevatedButton(
      onPressed: _isReconnectDisabled ? null : _handleConnect,
      child: Text(
        _isReconnectDisabled 
          ? 'Preparing...' 
          : 'Connect',
      ),
    );
  }
}
```

**Impact:**
- Gives ads 3 seconds to load
- Reduces user abandonment during load
- Show rate: +10-15%

```dart
// Track user connection patterns for targeting
class ConnectionUsageTracker {
  Future<void> recordConnection() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().substring(0, 10);
    final key = 'connections_$today';
    final count = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, count + 1);
    
    // Update 7-day rolling total
    await _updateRollingTotal();
  }
  
  Future<void> _updateRollingTotal() async {
    final prefs = await SharedPreferences.getInstance();
    int total = 0;
    
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key = 'connections_${date.toString().substring(0, 10)}';
      total += prefs.getInt(key) ?? 0;
    }
    
    await prefs.setInt('connections_last_7_days', total);
  }
}
```

**Files to create:**
- NEW: `lib/shared/services/targeting_optimizer.dart` (150 lines)

**Files to modify:**
- `lib/modules/main/presentation/widgets/ads/strategy/google_ad_strategy.dart` - Add dynamic keywords
- `lib/modules/main/presentation/screens/main_screen.dart` - Add reconnect delay
- `lib/modules/core/vpn.dart` - Track connections

---

## **Phase 4: Performance Monitoring Dashboard** (Week 2-3, Days 4-6)

**Objective:** Real-time visibility for debugging and optimization

### **4.1 Create Dashboard Screen** (*Day 1-2*)

**File:** `lib/modules/settings/presentation/screens/ad_performance_dashboard.dart` (280 lines)

**Features:**
- Current ad readiness state
- Rotation status and position
- Last 24h metrics
- Calculated KPIs
- Network comparison
- Export logs

```dart
class AdPerformanceDashboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceTracker = ref.watch(adPerformanceTrackerProvider);
    final adReadiness = ref.watch(adReadinessCoordinatorProvider);
    final rotationManager = ref.watch(rotationManagerProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text('Ad Performance Dashboard')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAdReadinessSection(adReadiness),
            SizedBox(height: 24),
            _buildRotationStatusSection(rotationManager),
            SizedBox(height: 24),
            _buildLast24hMetricsSection(performanceTracker),
            SizedBox(height: 24),
            _buildKPIsSection(performanceTracker),
            SizedBox(height: 24),
            _buildNetworkComparisonSection(performanceTracker),
            SizedBox(height: 24),
            _buildPositionPerformanceSection(performanceTracker),
            SizedBox(height: 24),
            _buildExportSection(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAdReadinessSection(AdReadinessState state) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ad Readiness', style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),
            SizedBox(height: 12),
            _buildStatusRow('Privacy Accepted', state.privacyAccepted),
            _buildStatusRow('Consent Complete', state.consentComplete),
            _buildStatusRow('AdMob Initialized', state.adMobInitialized),
            _buildStatusRow('Can Load Ads', state.canLoadAds),
            SizedBox(height: 8),
            Text('ATT Status: ${state.attStatus.name}'),
            Text('Consent Type: ${state.canUsePersonalizedAds ? "Personalized" : "Non-personalized"}'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRotationStatusSection(AdRotationManager? manager) {
    if (manager == null || !manager.isRotating) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Not rotating (user connected or no cycle active)'),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rotation Status', style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),
            SizedBox(height: 12),
            Text('Current Position: ${manager.currentPosition}/${manager.maxAdsPerCycle}'),
            Text('Session ID: ${manager.sessionId}'),
            Text('Cycle Duration: ${_formatDuration(manager.cycleStartTime)}'),
            Text('Next Ad Preloading: ${manager.isLoadingNext ? "Yes" : "No"}'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLast24hMetricsSection(AdPerformanceTracker tracker) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last 24 Hours', style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),
            SizedBox(height: 12),
            _buildMetricRow('Requests', tracker.totalRequests24h),
            _buildMetricRow('Impressions', tracker.totalImpressions24h),
            _buildMetricRow('Clicks', tracker.totalClicks24h),
            _buildMetricRow('Cycles', tracker.totalCycles24h),
            _buildMetricRow('Ads Shown', tracker.totalAdsShown24h),
          ],
        ),
      ),
    );
  }
  
  Widget _buildKPIsSection(AdPerformanceTracker tracker) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Key Performance Indicators', style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),
            SizedBox(height: 12),
            _buildKPIRow('Show Rate', '${(tracker.showRate * 100).toStringAsFixed(1)}%'),
            _buildKPIRow('CTR', '${(tracker.ctr * 100).toStringAsFixed(2)}%'),
            _buildKPIRow('Avg Ads/Cycle', tracker.avgAdsPerCycle.toStringAsFixed(2)),
            _buildKPIRow('Avg Load Time', '${tracker.avgLoadTime}ms'),
            _buildKPIRow('Est. Daily Revenue', '\${_estimateRevenue(tracker).toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNetworkComparisonSection(AdPerformanceTracker tracker) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Network Comparison', style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),
            SizedBox(height: 12),
            Table(
              border: TableBorder.all(),
              children: [
                TableRow(children: [
                  _buildTableHeader('Network'),
                  _buildTableHeader('Fill Rate'),
                  _buildTableHeader('eCPM'),
                  _buildTableHeader('Avg Load'),
                ]),
                _buildNetworkRow('AdMob', tracker),
                _buildNetworkRow('Facebook', tracker),
                _buildNetworkRow('AppLovin', tracker),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPositionPerformanceSection(AdPerformanceTracker tracker) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Position Performance', style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),
            SizedBox(height: 12),
            ...tracker.impressionsByPosition.entries.map((entry) {
              final position = entry.key;
              final impressions = entry.value;
              final clicks = tracker.clicksByPosition[position] ?? 0;
              final ctr = impressions > 0 ? (clicks / impressions * 100) : 0.0;
              
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Position $position'),
                    Text('$impressions imp'),
                    Text('${ctr.toStringAsFixed(2)}% CTR'),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExportSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _exportToCSV,
              icon: Icon(Icons.download),
              label: Text('Export to CSV'),
            ),
            SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _exportLogs,
              icon: Icon(Icons.article),
              label: Text('Export Debug Logs'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _exportToCSV() async {
    // Export metrics to CSV file
    final tracker = ref.read(adPerformanceTrackerProvider);
    final csv = generateCSV(tracker);
    await saveToFile(csv, 'ad_performance.csv');
  }
  
  void _exportLogs() async {
    // Export debug logs
    final logs = await getDebugLogs();
    await saveToFile(logs, 'ad_debug_logs.txt');
  }
}
```

### **4.2 Add Navigation to Dashboard** (*Day 2*)

**File:** `lib/modules/settings/presentation/screens/settings_screen.dart`

```dart
// In settings list, add:
SettingsItem(
  title: 'Ad Performance',
  subtitle: 'View ad metrics and diagnostics',
  icon: Icons.analytics,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdPerformanceDashboard()),
    );
  },
  // Only show in debug builds
  visible: kDebugMode,
),
```

### **4.3 Create Stats Model** (*Day 3*)

**File:** `lib/shared/models/ad_performance_stats.dart` (90 lines)

```dart
@freezed
class AdPerformanceStats with _$AdPerformanceStats {
  const factory AdPerformanceStats({
    required int totalRequests,
    required int totalImpressions,
    required int totalClicks,
    required int totalCycles,
    required int totalAdsShown,
    required Map<int, PositionStats> positionStats,
    required Map<String, NetworkStats> networkStats,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) = _AdPerformanceStats;
  
  factory AdPerformanceStats.fromJson(Map<String, dynamic> json) =>
      _$AdPerformanceStatsFromJson(json);
}

@freezed
class PositionStats with _$PositionStats {
  const factory PositionStats({
    required int position,
    required int impressions,
    required int clicks,
    required List<int> loadTimesMs,
  }) = _PositionStats;
  
  factory PositionStats.fromJson(Map<String, dynamic> json) =>
      _$PositionStatsFromJson(json);
}

@freezed
class NetworkStats with _$NetworkStats {
  const factory NetworkStats({
    required String network,
    required int requests,
    required int impressions,
    required int clicks,
    required double revenue,
    required int totalLoadTimeMs,
  }) = _NetworkStats;
  
  factory NetworkStats.fromJson(Map<String, dynamic> json) =>
      _$NetworkStatsFromJson(json);
}
```


---

## **Complete File Structure**

**New Files to Create (Total: 7 files, ~1,270 lines):**
```
lib/
  shared/
    services/
      ad_rotation_manager.dart (250 lines)
      ad_analytics_service.dart (200 lines)
      ad_performance_tracker.dart (120 lines)
      targeting_optimizer.dart (150 lines)
    models/
      ad_performance_stats.dart (90 lines)
  modules/
    settings/
      presentation/
        screens/
          ad_performance_dashboard.dart (280 lines)
  
  TOTAL NEW CODE: ~1,270 lines
```

**Files to Modify (Total: 5 files):**
```
lib/
  modules/
    main/
      presentation/
        widgets/
          ads/
            strategy/
              google_ad_strategy.dart (add rotation, mediation, targeting)
            ads_state.dart (add rotation fields)
        screens/
          main_screen.dart (add reconnect delay)
    settings/
      presentation/
        screens/
          settings_screen.dart (add dashboard link)
  shared/
    services/
      firebase_analytics_service.dart (minimal changes)

pubspec.yaml (no new dependencies needed)
```

---

## **Verification & Testing**

### **Week 1 Tests: Rotation + Analytics**

**Test 1: Single Rotation Cycle**
1. User disconnects VPN
2. Verify 5 ads show sequentially
3. Check timing: Ad 1 at 0s, Ad 2 at 10s, Ad 3 at 20s, Ad 4 at 30s, Ad 5 at 40s
4. Confirm countdown ends at 60s
5. Check logs for parallel loading (Ad 2 loads while Ad 1 shows)

**Expected Logs:**
```
0s:  🔌 User disconnected
0s:  📊 Rotation cycle started: session_abc123
0s:  → Loading Ad #1...
7s:  ✅ Ad #1 loaded (7000ms)
7s:  👁️ Ad #1 impression
7s:  ⏱️ Countdown: 60
7s:  → Preloading Ad #2 (parallel)...
10s: ✅ Ad #2 preloaded (3000ms)
17s: 👁️ Ad #2 impression (cache hit)
17s: → Preloading Ad #3 (parallel)...
20s: ✅ Ad #3 preloaded (3000ms)
27s: 👁️ Ad #3 impression (cache hit)
...
```

**Test 2: Analytics Verification**
1. Check Firebase Console for events:
   - `ad_rotation_cycle_started`
   - `ad_position_load_success` (positions 1-5)
   - `ad_position_impression` (positions 1-5)
   - `ad_preload_success` (positions 2-5)
   - `ad_cache_hit` (positions 2-5)
2. Verify all parameters present (session_id, position, timing)

**Test 3: User Reconnects Mid-Cycle**
1. User disconnects → Ad #1 shows → Ad #2 shows
2. User reconnects at 20s mark
3. Verify rotation stops cleanly
4. Check `ad_rotation_cycle_stopped` event (reason: 'user_reconnected', ads_shown: 2)
5. Confirm no memory leaks (ads disposed)

**Test 4: Load Failure Recovery**
1. Simulate network failure for Ad #3
2. Verify cycle continues with Ad #4
3. Check `ad_position_load_failure` event logged
4. Confirm user sees Ads 1, 2, skip 3, see 4, 5

### **Week 2 Tests: Targeting + Dashboard**

**Test 5: Dynamic Keywords**
1. Simulate casual user (< 5 connections/day)
2. Check ad request includes: 'free vpn', 'vpn trial'
3. Simulate power user (> 15 connections/day)
4. Check ad request includes: 'business vpn', 'premium vpn'
5. Verify keywords change with time of day

**Test 6: Reconnect Delay**
1. User disconnects
2. Verify reconnect button disabled for 3 seconds
3. Check "Preparing..." message shows
4. After 3s, verify button enabled
5. Confirm show rate improved

**Test 7: Dashboard Accuracy**
1. Generate known metrics (10 cycles, 50 impressions, 2 clicks)
2. Open Ad Performance Dashboard
3. Verify all numbers match
4. Check KPI calculations correct:
   - Show rate = impressions / requests
   - CTR = clicks / impressions
   - Avg ads/cycle = total_ads / total_cycles
5. Export CSV and validate data

**Test 8: End-to-End System**
1. Fresh user: Install → Accept privacy → Disconnect
2. Verify 5-ad rotation with analytics
3. User reconnects → disconnects again
4. Verify fresh 5-ad cycle starts
5. Check dashboard shows 10 total impressions
6. Simulate 24 hours → verify metrics reset

**Test 9: Performance Under Load**
1. Rapid connect/disconnect (stress test)
2. Monitor memory usage (no leaks)
3. Check ad disposal working
4. Verify no crashes
5. Confirm analytics queue doesn't overflow

**Test 10: Network Switching**
1. Start on WiFi → disconnect → Ad #1 loads
2. Switch to Cellular mid-cycle → Ad #2 loads
3. Verify rotation continues smoothly
4. Check IP consistency within each ad
5. Confirm no fraud flags

---

## **Expected Outcomes**

### **Week 1: Rotation + Analytics**

**Metrics:**
- Impressions/day: 538 → 2,150 (+300%)
- Ads per cycle: 1 → 4-5
- Show rate: 30% → 35% (first load still slow)
- Revenue/day: $0.14 → $0.56 (+300%)

**What you'll see in Firebase:**
- 20+ new event types
- Position-specific performance data
- Preload success rate: ~85%
- Cache hit rate: ~90% (positions 2-5)

### **Week 2: Targeting + UX + Dashboard**

**Metrics:**
- eCPM: $0.26 (unchanged, AdMob only)
- Match rate: 41% → 52% (+27% from targeting)
- Show rate: 35% → 50% (+43% from UX delay)
- Impressions/day: 2,150 → 3,150 (+47%)
- Revenue/day: $0.56 → $0.82 (+46%)

### **Week 3: Optimization + Stabilization**

**Metrics:**
- Show rate: 50% → 52% (from data-driven tweaks)
- Impressions/day: 3,150 → 3,250 (+3%)
- Revenue/day: $0.82 → $0.85 (+4%)

**Dashboard Insights:**
- Position 1: Lowest CTR (users skip fast)
- Position 3: Highest CTR (users engaged)
- Best time: Evening (7-10pm) highest eCPM
- Casual users: Lower CTR but more impressions
- Power users: Higher CTR, engage more

### **Month 1: Stabilized Performance**

**Conservative:**
- 2,800 impressions/day
- $0.70/day revenue
- $21/month = **+1,650% from current $1.20/month**

**Realistic:**
- 3,250 impressions/day
- $0.85/day revenue
- $25.50/month = **+2,025% from current $1.20/month**

**Optimistic:**
- 3,600 impressions/day  
- $0.95/day revenue
- $28.50/month = **+2,275% from current $1.20/month**

### **At Scale (10,000 DAU):**
- 32,500 impressions/day
- $8.50/day revenue
- $255/month
- **$3,060/year per 10k DAU**

### **Future: Add Mediation Later**
When ready to integrate Facebook Audience Network & AppLovin MAX:
- Expected eCPM increase: $0.26 → $0.35 (+35%)
- Would bring revenue to: $1.15-1.40/day
- At 10k DAU: $4,200-5,000/year

---

## **Rollout Strategy**

### **Phase 1 Rollout: Rotation + Analytics (Week 1)**

**Day 1-4:** Development
**Day 5:** Internal testing

**Day 6-7:** Beta rollout
- 5% of users (flag in Firebase Remote Config)
- Monitor closely:
  - Crash rate (<0.1% acceptable)
  - Show rate trending up
  - Analytics data flowing
- Hotfix if critical issues

**Day 8-10:** Gradual expansion
- Day 8: 10% users
- Day 9: 25% users
- Day 10: 50% users

**Day 11:** Full rollout (100%)

### **Phase 2 Rollout: Targeting + UX (Week 2)**

**Day 1-3:** Development
**Day 4:** Internal testing

**Day 5-6:** Beta (10% users)
- Monitor match rate improvement
- Check reconnect delay UX
- Verify no negative feedback

**Day 7-10:** Gradual expansion
- Day 7: 25% users
- Day 8: 50% users
- Day 9-10: 100% users

### **Phase 3 Rollout: Dashboard + Optimizations (Week 2-3)**

**Day 1-2:** Development
**Day 3:** Internal testing

**Day 4:** Beta (25% users)
- Test dashboard accuracy
- Verify export functionality

**Day 5:** Full rollout (100%)

### **Rollback Triggers**

**Critical (immediate rollback):**
- Crash rate > 1%
- Revenue drop > 30%
- Multiple user complaints about ads

**Warning (investigate, potential rollback):**
- Crash rate > 0.5%
- Revenue drop > 15%
- Show rate not improving
- Memory leaks detected

**Rollback Procedure:**
1. Flip Firebase Remote Config flag
2. Force old code path
3. Investigate issue
4. Fix and re-deploy

---

## **Success Criteria**

### **Must Achieve (Week 3):**
- ✅ Daily revenue > $0.70 (+400% from current $0.14)
- ✅ Impressions/day > 2,800 (+420%)
- ✅ No increase in crash rate
- ✅ App ratings stable (>4.0★)
- ✅ 5 ads showing per cycle
- ✅ All analytics events firing

### **Should Achieve (Month 1):**
- ✅ Daily revenue > $0.85 (+507%)
- ✅ Show rate > 50%
- ✅ eCPM stable at $0.26
- ✅ Match rate > 52%
- ✅ Dashboard showing accurate data

### **Stretch Goals (Month 2):**
- ✅ Daily revenue > $1.00 (+615%)
- ✅ Show rate > 55%
- ✅ Match rate > 55%
- ✅ 90%+ cache hit rate (positions 2-5)

---

## **Risk Mitigation**

### **Risk 1: Rotation Complexity Causing Bugs**
**Probability:** Medium  
**Impact:** High  
**Mitigation:**
- Comprehensive unit tests
- Staged rollout (5% → 100%)
- Detailed logging for debugging
- Quick rollback capability

### **Risk 2: User Fatigue (Too Many Ads)**
**Probability:** Medium  
**Impact:** Medium  
**Mitigation:**
- Monitor app ratings daily
- A/B test: 3 ads vs 5 ads
- Add "feedback" button
- Reduce frequency if ratings drop

### **Risk 3: Match Rate Not Improving Enough**
**Probability:** Medium  
**Impact:** Low  
**Mitigation:**
- A/B test different keyword sets
- Monitor Firebase for keyword performance
- Iterate on user segmentation
- Fall back to static keywords if needed

### **Risk 4: IP Mismatch False Positives**
**Probability:** Low  
**Impact:** High  
**Mitigation:**
- All ads load while disconnected (same IP)
- Add IP validation in analytics
- Monitor AdMob policy warnings
- Document IP consistency for review

### **Risk 5: Analytics Overhead**
**Probability:** Low  
**Impact:** Low  
**Mitigation:**
- Batch analytics events
- Async logging
- Minimal data per event
- Performance monitoring

---

## **Documentation Requirements**

### **Code Documentation:**
- [ ] Inline comments for rotation logic
- [ ] Architecture diagram (rotation flow)
- [ ] Analytics event catalog
- [ ] Targeting optimization guide

### **User Documentation:**
- [ ] Release notes (v2.7.0)
- [ ] Known issues list
- [ ] Performance improvements summary

### **Internal Documentation:**
- [ ] Runbook for debugging rotation issues
- [ ] Analytics dashboard guide
- [ ] Keyword optimization playbook
- [ ] Rollback procedures

---

## **Summary: Complete Ad Revenue Optimization (AdMob Only)**

**What We're Building:**
A sophisticated ad rotation system that shows 5 ads per 60-second disconnect cycle, with parallel loading, comprehensive analytics, dynamic targeting, UX optimizations, and real-time performance monitoring.

**Why It Works:**
1. **Parallel Loading:** Load next ad while showing current → no wait time
2. **IP Consistency:** All ads load while disconnected → no fraud risk
3. **Smart Targeting:** Dynamic keywords based on user behavior → better match rate
4. **UX Optimization:** 3-second reconnect delay → more time to load ads
5. **Data-Driven:** Comprehensive analytics → continuous optimization

**Expected Impact:**
- Revenue: $0.14/day → $0.85/day (**+507%**)
- Impressions: 538/day → 3,250/day (**+504%**)
- At 10k DAU: **$3,060/year**

**Future Enhancement:**
When ready to add mediation (Facebook + AppLovin):
- Additional eCPM increase: +35% ($0.26 → $0.35)
- Would bring revenue to: $1.15-1.40/day
- At 10k DAU: $4,200-5,000/year

**Timeline:** 2-3 weeks end-to-end

**Complexity:** Medium (1,270 lines of new code)

**Risk:** Medium (mitigated with staged rollout)

**ROI:** Excellent (6x revenue increase)

---

## **Next Steps**

**Ready to start implementation?**

1. **Phase 1 (Week 1):** Ad rotation + analytics
2. **Phase 2 (Week 2):** Targeting + UX optimization  
3. **Phase 3 (Week 2-3):** Dashboard + optimization
4. **Future:** Add mediation when ready (Facebook + AppLovin)

**I can build:**
- Complete `AdRotationManager` with parallel loading
- Full `AdAnalyticsService` with all events
- `TargetingOptimizer` with dynamic keywords
- Dashboard UI

**What would you like me to implement first?**

---

## **Phase 2: Comprehensive Firebase Analytics** (Week 1, parallel)

**Objective:** Track every ad metric to identify optimization opportunities

**Analytics Events:**

1. **Ad Lifecycle Events:**
   - `ad_rotation_cycle_started` - When disconnect happens
   - `ad_position_load_started` - Parameters: position (1-4), session_id
   - `ad_position_load_success` - Parameters: position, load_duration_ms, session_id
   - `ad_position_load_failure` - Parameters: position, error_code, error_message
   - `ad_position_impression` - Parameters: position, display_duration_s, session_id
   - `ad_position_clicked` - Parameters: position, session_id
   - `ad_rotation_cycle_completed` - Parameters: total_ads_shown, session_id

2. **Performance Metrics:**
   - `ad_cache_hit` - Parameters: position, preload_success
   - `ad_cache_miss` - Parameters: position, reason
   - `ad_preload_started` - Parameters: next_position
   - `ad_preload_completed` - Parameters: position, success, duration_ms

3. **Session Tracking:**
   - `ad_session_started` - When user disconnects
   - `ad_session_ended` - Parameters: total_impressions, total_clicks, duration_s
   - `ad_revenue_estimate` - Parameters: impressions, estimated_revenue

4. **User Segments:**
   - Set user properties: `ad_consent_type` (personalized/non-personalized)
   - Set user properties: `avg_session_duration_s`
   - Set user properties: `total_ad_views_lifetime`

**Steps:**

5. **Create AdAnalyticsService** (*Day 1-2, parallel*)
   - Wrapper around FirebaseAnalytics
   - Pre-defined event methods
   - Automatic session_id generation
   - Revenue estimation logic

6. **Integrate analytics into GoogleAdStrategy** (*Day 2-3*)
   - Track all load attempts with timing
   - Track all impressions with position
   - Track clicks and errors
   - Calculate and log show rate

7. **Create AdPerformanceTracker** (*Day 3*)
   - Real-time KPI calculation
   - Session aggregation
   - Export to SharedPreferences for persistence

**Files to create:**
- NEW: `lib/shared/services/ad_analytics_service.dart` (180 lines)
- NEW: `lib/shared/services/ad_performance_tracker.dart` (100 lines)

**Files to modify:**
- `lib/modules/main/presentation/widgets/ads/strategy/google_ad_strategy.dart` - Add comprehensive analytics calls
- `lib/shared/services/firebase_analytics_service.dart` - Add ad-specific helper methods

---

## **Phase 3: Ad Mediation** (Week 2)

**Objective:** Add Facebook Audience Network + AppLovin MAX for higher eCPM through bidding

**Dependencies:**
```yaml
facebook_audience_network: ^1.3.0
applovin_max: ^3.9.0
```

**Steps:**

8. **Set up Facebook Audience Network** (*Day 1-2*)
   - Add SDK dependency
   - Configure placement IDs in .env
   - Create FacebookAdAdapter
   - Test fill rate

9. **Set up AppLovin MAX** (*Day 2-3*)
   - Add SDK dependency
   - Configure ad units in .env
   - Create AppLovinAdAdapter
   - Test bidding

10. **Create MediationManager** (*Day 3-4*)
    - Unified interface for all networks
    - Waterfall logic: AdMob → Facebook → AppLovin
    - Track fill rate per network
    - Auto-optimize order based on eCPM

11. **Update GoogleAdStrategy to use mediation** (*Day 4-5*)
    - Replace direct AdMob calls with MediationManager
    - Track which network served each ad
    - Log network performance analytics

**Files to create:**
- NEW: `lib/shared/services/ad_mediation_manager.dart` (150 lines)
- NEW: `lib/shared/adapters/facebook_ad_adapter.dart` (100 lines)
- NEW: `lib/shared/adapters/applovin_ad_adapter.dart` (100 lines)

**Files to modify:**
- `lib/modules/main/presentation/widgets/ads/strategy/google_ad_strategy.dart` - Use mediation
- `.env` - Add Facebook and AppLovin credentials

---

## **Phase 4: Enhanced Targeting** (Week 2, parallel)

**Objective:** Increase match rate from 41% to 60% with better targeting

**Steps:**

12. **Implement dynamic keyword selection** (*Day 1*)
    - User behavior tracking (connection frequency, duration)
    - Context-aware keywords (time of day, location)
    - Category rotation to test performance

13. **Add floor price optimization** (*Day 2*)
    - Set minimum bid: $0.15 (filter low-paying ads)
    - A/B test: $0.10, $0.15, $0.20
    - Track revenue vs fill rate tradeoff

14. **Implement custom targeting** (*Day 3*)
    - User lifecycle stage (new, active, churned)
    - VPN usage patterns (casual, power user)
    - Device type targeting (premium devices = higher bids)

**Files to create:**
- NEW: `lib/shared/services/targeting_optimizer.dart` (120 lines)

**Files to modify:**
- `lib/modules/main/presentation/widgets/ads/strategy/google_ad_strategy.dart` - Use dynamic keywords and floor price

---

## **Phase 5: Performance Monitoring Dashboard** (Week 3)

**Objective:** Real-time visibility into ad performance for debugging and optimization

**Steps:**

15. **Create debug screen** (*Day 1-2*)
    - Show current ad readiness state
    - Display rotation position and timing
    - Show real-time metrics (last 24h)
    - Export logs to file

16. **Add calculated KPIs** (*Day 2*)
    - Show rate: impressions / requests
    - Fill rate: served / requests
    - CTR: clicks / impressions
    - Estimated daily revenue

17. **Add network comparison** (*Day 3*)
    - Table showing all networks
    - Fill rate, eCPM, latency per network
    - Identify best performer

**Files to create:**
- NEW: `lib/modules/settings/presentation/screens/ad_performance_dashboard.dart` (250 lines)
- NEW: `lib/shared/models/ad_performance_stats.dart` (80 lines)

---

## **Verification**

**Week 1 Tests:**
1. Verify 4 ads show per disconnect cycle
2. Confirm analytics events firing correctly
3. Validate timing: 10s display + 5s cooldown
4. Check preloading working (next ad ready instantly)

**Week 2 Tests:**
1. Verify mediation switching networks correctly
2. Confirm all 3 networks attempting to fill
3. Validate targeting improvements (match rate trending up)
4. Check floor pricing filtering low bids

**Week 3 Tests:**
1. Dashboard showing accurate metrics
2. All KPIs calculating correctly
3. Network comparison showing real data
4. Export functionality working

**Success Criteria:**
- ✅ 4 ads showing per 60s cycle (confirmed in logs)
- ✅ All analytics events present in Firebase console
- ✅ Mediation working (see multiple network attempts)
- ✅ Match rate > 50% (up from 41%)
- ✅ Daily revenue > $0.40 (+196% minimum)

---

## **Expected Outcomes**

**Conservative (Week 2):**
- 1,800 impressions/day (3.3x from rotation)
- $0.35/day revenue (+159%)
- Show rate: 40%

**Realistic (Week 3):**
- 2,100 impressions/day (4x from rotation)
- $0.52/day revenue (+285%)
- eCPM: $0.35 (from mediation)
- Show rate: 50%

**Optimistic (Month 1):**
- 2,500 impressions/day (4.6x)
- $0.70/day revenue (+418%)
- eCPM: $0.40 (optimized mediation)
- Match rate: 60%

---

## **Decisions**

- **No preloading during VPN connection** - Avoids wrong IP targeting
- **4 ads max per cycle** - Balance revenue vs UX
- **15-second cycle** (10s show + 5s cooldown) - Optimal for preloading
- **Analytics-first approach** - Track everything to optimize
- **Mediation waterfall** - Try AdMob first, fallback to Facebook/AppLovin
- **Floor price: $0.15** - Filter low-value ads

---

## **Risks & Mitigation**

**Risk 1: Ad fatigue** (showing 4 ads annoying users)
- **Mitigation:** Monitor ratings, A/B test 2 vs 4 ads

**Risk 2: Rotation complexity** causing bugs
- **Mitigation:** Comprehensive testing, gradual rollout (10% → 50% → 100%)

**Risk 3: Mediation reducing fill rate**
- **Mitigation:** Start with AdMob only, add networks incrementally

**Risk 4: Analytics overhead** slowing app
- **Mitigation:** Batch events, async logging, minimal data

---

## **Rollout Plan**

**Week 1:** Beta to 10% users
- Monitor crash rate (<0.1%)
- Validate rotation working
- Check analytics data quality

**Week 2:** Scale to 50% users
- Compare revenue vs control group
- Optimize targeting based on data
- Fix any issues

**Week 3:** Full rollout 100%
- Monitor overall revenue increase
- Dashboard for ongoing optimization
- Document learnings
