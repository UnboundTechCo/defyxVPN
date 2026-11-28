import 'dart:async';
import 'package:defyx_vpn/shared/services/ump_consent_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class UmpService {
  final UmpConsentCacheService? _cacheService;

  UmpService([this._cacheService]);

  /// Request UMP consent flow
  ///
  /// The caller (AdReadinessCoordinator) determines whether this should run
  /// based on ATT status and platform. This method just executes the UMP flow.
  /// Returns whether a consent form was shown.
  Future<bool> requestConsentWithATT({
    required WidgetRef ref,
    required VoidCallback onDone,
  }) async {
    debugPrint('Starting UMP consent flow...');
    return requestConsent(onDone: onDone);
  }

  /// Returns whether a consent form was shown (the user answered again, or
  /// dismissed it).
  Future<bool> requestConsent({required VoidCallback onDone}) async {
    final completer = Completer<bool>();
    var formShown = false;

    void finish() {
      if (!completer.isCompleted) {
        onDone();
        completer.complete(formShown);
      }
    }

    // Always ask: Google requires a consent info update on every launch (the
    // consent may have expired or the requirements changed). The form only
    // appears when consent is actually required.
    final consentInfo = ConsentInformation.instance;
    final params = ConsentRequestParameters(tagForUnderAgeOfConsent: false);

    debugPrint('Requesting UMP consent info update...');
    consentInfo.requestConsentInfoUpdate(
      params,
      () => _onConsentInfoSuccess(
        consentInfo,
        finish,
        onFormShown: () => formShown = true,
      ),
      (FormError error) => _onConsentInfoFailure(error, finish),
    );

    return completer.future;
  }

  void _onConsentInfoSuccess(
    ConsentInformation consentInfo,
    VoidCallback onDone, {
    required VoidCallback onFormShown,
  }) async {
    try {
      final status = await consentInfo.getConsentStatus();
      debugPrint('📋 UMP consent status: ${status.name}');

      if (await consentInfo.isConsentFormAvailable() &&
          status == ConsentStatus.required) {
        ConsentForm.loadConsentForm(
          (ConsentForm form) => _onFormLoaded(form, onDone, onFormShown),
          (FormError error) => _onFormLoadFailed(error, onDone),
        );
      } else {
        // Cache consent status
        await _cacheConsentStatus(status);
        onDone();
      }
    } catch (e) {
      debugPrint('⚠️ Error in _onConsentInfoSuccess: $e');
      onDone();
    }
  }

  void _onConsentInfoFailure(FormError error, VoidCallback onDone) {
    debugPrint('UMP consent info request failed: ${error.message}');
    onDone();
  }

  void _onFormLoaded(
    ConsentForm form,
    VoidCallback onDone,
    VoidCallback onFormShown,
  ) {
    debugPrint('UMP consent form loaded, showing to user...');
    onFormShown();
    form.show((FormError? error) => _onFormDismissed(error, onDone));
  }

  void _onFormLoadFailed(FormError error, VoidCallback onDone) {
    debugPrint('UMP consent form failed to load: ${error.message}');
    onDone();
  }

  void _onFormDismissed(FormError? error, VoidCallback onDone) async {
    try {
      if (error != null) {
        debugPrint(
          '⚠️ UMP consent form dismissed with error: ${error.message}',
        );
      } else {
        debugPrint('✅ UMP consent form completed');
      }

      // Cache consent status after form dismissal
      final status = await ConsentInformation.instance.getConsentStatus();
      await _cacheConsentStatus(status);
    } catch (e) {
      debugPrint('⚠️ Error handling form dismissal: $e');
    } finally {
      onDone();
    }
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
      debugPrint('Failed to cache UMP consent: $e');
    }
  }

  Future<bool> canShowAds() async {
    // Try cache first for fast path
    if (_cacheService != null) {
      final cachedResult = await _cacheService.getCachedCanShowAds();
      if (cachedResult != null) {
        debugPrint('Using cached canShowAds: $cachedResult');
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
