// Ad countdown: AdMob display time, pausing while unseen, preload timing.

import 'package:defyx_vpn/modules/main/presentation/widgets/ads/ads_state.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('an AdMob ad stays up 30s, paused while unseen, and the next '
      'one is requested 10s before the end', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ads = container.read(adsProvider.notifier);
    int countdown() => container.read(adsProvider).countdown;
    var preloads = 0;
    ads.setAdPreloadCallback(() => preloads++);

    ads.setAdLoaded(true); // An AdMob ad is showing.
    ads.startCountdownTimer(seconds: adMobDisplaySeconds);
    expect(countdown(), 30);

    await tester.pump(const Duration(seconds: 5));
    expect(countdown(), 25);

    ads.setAdOnScreen(false); // Another page covers the main screen.
    await tester.pump(const Duration(seconds: 10));
    expect(countdown(), 25);

    ads.setAdOnScreen(true);
    ads.setAppInForeground(false); // App in the background.
    await tester.pump(const Duration(seconds: 10));
    expect(countdown(), 25);

    ads.setAppInForeground(true);
    await tester.pump(const Duration(seconds: 14));
    expect(countdown(), 11);
    expect(preloads, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(countdown(), adMobPreloadLeadSeconds);
    expect(preloads, 1);

    ads.stopCountdownTimer();
  });

  testWidgets('in-house ads keep 25s and never request an AdMob ad', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ads = container.read(adsProvider.notifier);
    int countdown() => container.read(adsProvider).countdown;
    var preloads = 0;
    ads.setAdPreloadCallback(() => preloads++);

    ads.setCustomAdData('https://ads.example/a.png', 'https://example.com');
    ads.startCountdownTimer();
    expect(countdown(), countdownDuration);

    await tester.pump(const Duration(seconds: 20));
    expect(preloads, 0);

    ads.stopCountdownTimer();
  });

  test('the label is decided when the ad appears, not halfway', () {
    // A rotating ad says "Next ad" from its first second, before the next
    // one is even fetched.
    expect(
      countdownLabel(const AdsState(countdown: 30), nextAdExpected: true),
      'Next ad in 30s',
    );
    // The last ad of the rotation says "Closing" from the start.
    expect(
      countdownLabel(
        const AdsState(countdown: 30, rotationCount: maxAdRotations),
        nextAdExpected: true,
      ),
      'Closing in 30s',
    );
    // Not rotating (the connect tap's ad, in-house ads), or the next ad
    // could not be fetched.
    expect(
      countdownLabel(const AdsState(countdown: 12), nextAdExpected: false),
      'Closing in 12s',
    );
  });
}
