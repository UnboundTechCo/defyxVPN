// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:defyx_vpn/modules/main/presentation/widgets/privacy_notice_dialog.dart';
import 'package:defyx_vpn/shared/services/telemetry_consent_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('telemetry is opt-in by default in the privacy notice', (
    tester,
  ) async {
    bool? selectedTelemetry;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: PrivacyNoticeDialog(
            onAccept: (telemetryOptIn) async {
              selectedTelemetry = telemetryOptIn;
              return true;
            },
          ),
        ),
      ),
    );

    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(selectedTelemetry, isFalse);
  });

  test('telemetry consent persists explicit choices', () async {
    SharedPreferences.setMockInitialValues({});
    final telemetry = TelemetryConsentService();

    await telemetry.initialize();
    expect(telemetry.consent, TelemetryConsent.undecided);

    await telemetry.grant();
    expect(telemetry.consent, TelemetryConsent.granted);

    await telemetry.deny();
    expect(telemetry.consent, TelemetryConsent.denied);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('telemetry_consent_v1'), 'denied');
  });
}
