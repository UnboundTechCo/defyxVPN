// AdMob on/off decision and the per-launch consent flow.

import 'dart:async';

import 'package:defyx_vpn/app/ad_director_provider.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_settings.dart';
import 'package:defyx_vpn/shared/models/ad_readiness_state.dart';
import 'package:defyx_vpn/shared/providers/ad_readiness_coordinator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdEnvironmentNotifier', () {
    test('waits for the server settings, then decides', () async {
      bool? adMobDisabled; // Fresh install: nothing saved yet.
      final notifier = AdEnvironmentNotifier(
        () async => adMobDisabled,
        isMobile: true,
      );
      addTearDown(notifier.dispose);
      await pumpEventQueue();
      expect(notifier.state.isLoading, isTrue);

      adMobDisabled = false; // The splash screen saved the settings.
      await notifier.refresh();
      expect(notifier.state.value?.shouldInitializeAdMob, isTrue);
    });

    test('notifies only when the decision changes', () async {
      var adMobDisabled = false;
      final notifier = AdEnvironmentNotifier(
        () async => adMobDisabled,
        isMobile: true,
      );
      addTearDown(notifier.dispose);
      await pumpEventQueue();

      final seen = <AsyncValue<AdEnvironment>>[];
      final removeListener = notifier.addListener(
        seen.add,
        fireImmediately: false,
      );
      addTearDown(removeListener);

      await notifier.refresh(); // Same answer on every save...
      await notifier.refresh();
      expect(seen, isEmpty);

      adMobDisabled = true; // ...until the time zone gets listed.
      await notifier.refresh();
      expect(seen.single.value?.shouldInitializeAdMob, isFalse);
    });

    test('a save during a refresh is not lost', () async {
      final firstAnswerHeld = Completer<void>();
      final answers = [true, false];
      var calls = 0;
      final notifier = AdEnvironmentNotifier(() async {
        final answer = answers[calls++];
        if (calls == 1) await firstAnswerHeld.future;
        return answer;
      }, isMobile: true);
      addTearDown(notifier.dispose);

      unawaited(notifier.refresh()); // New settings while the first runs.
      firstAnswerHeld.complete();
      await pumpEventQueue();

      expect(calls, 2);
      expect(notifier.state.value?.adMobIsDisabled, isFalse);
    });

    test('desktop never initializes AdMob', () async {
      final notifier = AdEnvironmentNotifier(() async => true, isMobile: false);
      addTearDown(notifier.dispose);
      await pumpEventQueue();
      expect(notifier.state.value?.shouldInitializeAdMob, isFalse);
    });
  });

  test(
    'consent and AdMob setup are per launch; privacy acceptance is kept',
    () {
      // What older builds saved after the first successful run.
      const saved =
          '{"privacyAccepted":true,"attStatus":3,"consentComplete":true,'
          '"adMobInitialized":true,"canUsePersonalizedAds":true,'
          '"initAttempts":0,"version":1}';
      final restored = AdReadinessState.fromJsonString(saved);

      expect(restored.privacyAccepted, isTrue);
      expect(restored.consentComplete, isFalse);
      expect(restored.adMobInitialized, isFalse);
      expect(restored.canInitializeAdMob, isTrue);

      final resaved = AdReadinessState.fromJsonString(
        const AdReadinessState(
          privacyAccepted: true,
          consentComplete: true,
          adMobInitialized: true,
        ).toJsonString(),
      );
      expect(resaved.consentComplete, isFalse);
      expect(resaved.adMobInitialized, isFalse);
    },
  );

  test('flowline settings without fields read as empty lists', () {
    final empty = FlowlineSettings.fromJson({});
    expect(empty.disabledAdmob, isEmpty);
    expect(empty.baseUrls, isEmpty);

    final listed = FlowlineSettings.fromJson({
      'disabledAdmob': ['Asia/Tehran', 'general'],
      'backendUrls': ['https://example.com'],
    });
    expect(listed.disabledAdmob, ['asia/tehran', 'general']);
  });

  group('AdReadinessCoordinator.initializeAdFlow', () {
    const ump = MethodChannel('plugins.flutter.io/google_mobile_ads/ump');
    late bool canRequestAds;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      canRequestAds = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ump, (call) async {
            if (call.method == 'ConsentInformation#canRequestAds') {
              return canRequestAds;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ump, null);
    });

    Future<AdReadinessCoordinator> privacyAccepted() async {
      final coordinator = AdReadinessCoordinator();
      await pumpEventQueue();
      await coordinator.markPrivacyAccepted();
      return coordinator;
    }

    test('runs the consent check once when started twice', () async {
      final coordinator = await privacyAccepted();
      addTearDown(coordinator.dispose);

      var umpRuns = 0;
      final umpDone = Completer<void>();
      Future<void> runUmp(bool _) async {
        umpRuns++;
        await umpDone.future;
      }

      final first = coordinator.initializeAdFlow(onRunUMP: runUmp);
      final second = coordinator.initializeAdFlow(onRunUMP: runUmp);
      umpDone.complete();
      await Future.wait([first, second]);

      expect(umpRuns, 1);
    });

    test('keeps AdMob off when UMP says ads may not be requested', () async {
      final coordinator = await privacyAccepted();
      addTearDown(coordinator.dispose);

      await coordinator.initializeAdFlow(onRunUMP: (_) async {});

      expect(coordinator.state.consentComplete, isFalse);
      expect(coordinator.state.adMobInitialized, isFalse);
      expect(coordinator.state.canLoadAds, isFalse);
      expect(coordinator.state.lastError, 'UMP consent not obtained');
    });
  });
}
