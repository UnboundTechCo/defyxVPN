import 'package:defyx_vpn/shared/services/ump_consent_cache.dart';
import 'package:defyx_vpn/shared/providers/ad_personalization_provider.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class UmpService {
  final UmpConsentCacheService? _cacheService;

  UmpService([this._cacheService]);

  /// Request consent with ATT compliance (Apple requirement)
  ///
  /// If ATT denied → Skip UMP entirely (no tracking, use non-personalized ads)
  /// If ATT authorized → Show UMP for GDPR compliance
  /// If ATT notDetermined (iOS only) → Don't proceed (dialog not shown yet)
  Future<void> requestConsentWithATT({
    required WidgetRef ref,
    required VoidCallback onDone,
  }) async {
    // Check ATT status
    final attState = ref.read(adPersonalizationProvider);

    // iOS only: If ATT status is notDetermined, don't proceed
    // This means the dialog wasn't shown - likely Info.plist issue or device restriction
    // Android always returns 'authorized' so this check won't block Android
    if (Platform.isIOS &&
        attState.attStatus == TrackingStatus.notDetermined) {
      debugPrint(
        '⚠️ ATT dialog not shown (notDetermined) - Check Info.plist or device restrictions',
      );
      debugPrint('⚠️ NOT marking consent complete - waiting for ATT dialog');
      // Don't call onDone() - consent flow is NOT complete
      return;
    }

    // Check if we should request UMP based on ATT status (Apple compliance)
    final shouldRequestUMP = ref
        .read(adPersonalizationProvider.notifier)
        .shouldRequestUMP;

    if (!shouldRequestUMP) {
      // ATT denied/restricted - Skip UMP, proceed with non-personalized ads
      final attStatus = attState.attStatus;
      debugPrint(
        '⏭️ Skipping UMP (ATT $attStatus) - Using non-personalized ads',
      );
      onDone();
      return;
    }

    // ATT authorized (or Android) - Request UMP for GDPR compliance
    debugPrint('🔍 Requesting UMP consent (ATT authorized)');
    await requestConsent(onDone: onDone);
  }

  Future<void> requestConsent({required VoidCallback onDone}) async {
    // Check cache first to potentially skip UMP request
    if (_cacheService != null) {
      final canSkip = await _cacheService.canSkipConsentRequest();
      if (canSkip) {
        debugPrint('✅ Skipping UMP request - using cached consent');
        onDone();
        return;
      }
    }

    final consentInfo = ConsentInformation.instance;
    final params = ConsentRequestParameters(tagForUnderAgeOfConsent: false);

    debugPrint('🔍 Requesting UMP consent info update...');
    consentInfo.requestConsentInfoUpdate(
      params,
      () => _onConsentInfoSuccess(consentInfo, onDone),
      (FormError error) => _onConsentInfoFailure(error, onDone),
    );
  }

  void _onConsentInfoSuccess(
    ConsentInformation consentInfo,
    VoidCallback onDone,
  ) async {
    final status = await consentInfo.getConsentStatus();
    debugPrint('📋 UMP consent status: ${status.name}');

    if (await consentInfo.isConsentFormAvailable() &&
        status == ConsentStatus.required) {
      ConsentForm.loadConsentForm(
        (ConsentForm form) => _onFormLoaded(form, onDone),
        (FormError error) => _onFormLoadFailed(error, onDone),
      );
    } else {
      // Cache consent status
      await _cacheConsentStatus(status);
      onDone();
    }
  }

  void _onConsentInfoFailure(FormError error, VoidCallback onDone) {
    debugPrint('❌ UMP consent info request failed: ${error.message}');
    onDone();
  }

  void _onFormLoaded(ConsentForm form, VoidCallback onDone) {
    debugPrint('📄 UMP consent form loaded, showing to user...');
    form.show((FormError? error) => _onFormDismissed(error, onDone));
  }

  void _onFormLoadFailed(FormError error, VoidCallback onDone) {
    debugPrint('❌ UMP consent form failed to load: ${error.message}');
    onDone();
  }

  void _onFormDismissed(FormError? error, VoidCallback onDone) async {
    if (error != null) {
      debugPrint('⚠️ UMP consent form dismissed with error: ${error.message}');
    } else {
      debugPrint('✅ UMP consent form completed');
    }

    // Cache consent status after form dismissal
    final status = await ConsentInformation.instance.getConsentStatus();
    await _cacheConsentStatus(status);

    onDone();
  }

  Future<void> _cacheConsentStatus(ConsentStatus status) async {
    if (_cacheService == null) return;

    try {
      final canShowAds =
          status == ConsentStatus.obtained ||
          status == ConsentStatus.notRequired;
      final canRequestAds = status != ConsentStatus.required;

      await _cacheService.cacheConsentStatus(
        status: status,
        canShowAds: canShowAds,
        canRequestAds: canRequestAds,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to cache UMP consent: $e');
    }
  }

  Future<bool> canShowAds() async {
    // Try cache first for fast path
    if (_cacheService != null) {
      final cachedResult = await _cacheService.getCachedCanShowAds();
      if (cachedResult != null) {
        debugPrint('📦 Using cached canShowAds: $cachedResult');
        return cachedResult;
      }
    }

    // Fall back to UMP SDK
    final status = await ConsentInformation.instance.getConsentStatus();
    return status == ConsentStatus.obtained ||
        status == ConsentStatus.notRequired;
  }
}

/// Provider for UMP service with cache integration
final umpServiceProvider = Provider<UmpService>((ref) {
  final cacheService = ref.watch(umpConsentCacheServiceProvider);
  return UmpService(cacheService);
});
