import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class UmpService {
  static void requestConsent({required VoidCallback onDone}) {
    final consentInfo = ConsentInformation.instance;
    final params = ConsentRequestParameters(
      tagForUnderAgeOfConsent: false,
    );
    consentInfo.requestConsentInfoUpdate(
      params,
      () => _onConsentInfoSuccess(consentInfo, onDone),
      (FormError error) => _onConsentInfoFailure(error, onDone),
    );
  }

  static void _onConsentInfoSuccess(
    ConsentInformation consentInfo,
    VoidCallback onDone,
  ) async {
    final status = await consentInfo.getConsentStatus();

    if (await consentInfo.isConsentFormAvailable() &&
        status == ConsentStatus.required) {
      ConsentForm.loadConsentForm(
        (ConsentForm form) => _onFormLoaded(form, onDone),
        (FormError error) => _onFormLoadFailed(error, onDone),
      );
    } else {
      onDone();
    }
  }

  static void _onConsentInfoFailure(FormError error, VoidCallback onDone) {
    onDone();
  }

  static void _onFormLoaded(ConsentForm form, VoidCallback onDone) {
    form.show((FormError? error) => _onFormDismissed(error, onDone));
  }

  static void _onFormLoadFailed(FormError error, VoidCallback onDone) {
    onDone();
  }

  static void _onFormDismissed(FormError? error, VoidCallback onDone) {
    onDone();
  }
  
  static Future<bool> canShowAds() async {
    final status = await ConsentInformation.instance.getConsentStatus();
    return status == ConsentStatus.obtained ||
        status == ConsentStatus.notRequired;
  }
}
