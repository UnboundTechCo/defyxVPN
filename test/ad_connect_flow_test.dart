// AdMob ads show from the connect tap: held while disconnected, shown at the
// tap, kept through connecting and connected, removed on disconnect.

import 'package:defyx_vpn/app/ad_director_provider.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/ads_state.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/google_ad_strategy.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/internal_ad_strategy.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/providers/premium_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _refProvider = Provider<Ref>((ref) => ref);

ProviderContainer _container() {
  final container = ProviderContainer(
    // No real ad requests in tests: loads stop at the premium check.
    overrides: [adsAllowedProvider.overrideWithValue(false)],
  );
  addTearDown(container.dispose);
  return container;
}

NativeAd _ad() => NativeAd(
  adUnitId: 'test',
  factoryId: 'test',
  listener: NativeAdListener(),
  request: const AdRequest(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // The connection notifier listens to the native VPN events.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          const EventChannel('com.defyx.vpn_events'),
          MockStreamHandler.inline(onListen: (_, _) {}),
        );
  });
  tearDown(() => GoogleAdStrategy.debugHoldAd(null));

  group('which strategy fills the box', () {
    late ProviderContainer container;

    AdStrategyManager manager({required bool adMob}) {
      container = _container();
      final provider = Provider(
        (ref) => AdStrategyManager.create(
          ref: ref,
          environment: AdEnvironment(
            adMobIsDisabled: !adMob,
            isMobilePlatform: true,
            shouldInitializeAdMob: adMob,
          ),
        ),
      );
      return container.read(provider);
    }

    test('AdMob: from the connect tap on, nothing while disconnected', () {
      final m = manager(adMob: true);
      expect(m.getActiveStrategy(ConnectionStatus.disconnected), isNull);
      expect(m.getActiveStrategy(ConnectionStatus.error), isNull);
      expect(
        m.getActiveStrategy(ConnectionStatus.loading),
        isA<GoogleAdStrategy>(),
      );
      expect(
        m.getActiveStrategy(ConnectionStatus.analyzing),
        isA<GoogleAdStrategy>(),
      );

      // Connected: the AdMob ad from the tap while it is on screen...
      GoogleAdStrategy.debugHoldAd(_ad());
      m.googleStrategy!.onConnectionStateChanged(
        ref: container.read(_refProvider),
        previous: ConnectionStatus.disconnected,
        current: ConnectionStatus.loading,
        hasInitialized: true,
        onRefreshNeeded: () {},
      );
      expect(
        m.getActiveStrategy(ConnectionStatus.connected),
        isA<GoogleAdStrategy>(),
      );
      // ...and while disconnected only when an AdMob ad is on screen.
      expect(
        m.getActiveStrategy(ConnectionStatus.disconnected),
        isA<GoogleAdStrategy>(),
      );
    });

    test(
      'AdMob: connected with no AdMob ad on screen gets the in-house ad',
      () {
        // E.g. the app reopened while connected: the tap's ad died with it.
        final m = manager(adMob: true);
        expect(m.googleStrategy!.shownThisConnection, isFalse);
        expect(
          m.getActiveStrategy(ConnectionStatus.connected),
          isA<InternalAdStrategy>(),
        );
      },
    );

    test('AdMob off: in-house ads while connected only', () {
      final m = manager(adMob: false);
      expect(
        m.getActiveStrategy(ConnectionStatus.connected),
        isA<InternalAdStrategy>(),
      );
      expect(m.getActiveStrategy(ConnectionStatus.loading), isNull);
      expect(m.getActiveStrategy(ConnectionStatus.disconnected), isNull);
    });
  });

  group('in-house ads and DXcore switches', () {
    late ProviderContainer container;
    late AdStrategyManager m;

    setUp(() {
      container = _container();
      // Let the notifier's async state saves finish before the container
      // goes (teardowns run last-added first).
      addTearDown(pumpEventQueue);
      m = container.read(
        Provider(
          (ref) => AdStrategyManager.create(
            ref: ref,
            environment: const AdEnvironment(
              adMobIsDisabled: true,
              isMobilePlatform: true,
              shouldInitializeAdMob: false,
            ),
          ),
        ),
      );
    });

    ConnectionStateNotifier conn() =>
        container.read(connectionStateProvider.notifier);
    String? inHouseAd() => container.read(adsProvider).customImageUrl;

    test('an in-house ad stays through a switch and is not replaced', () {
      container
          .read(adsProvider.notifier)
          .setCustomAdData('https://ads.example/a.png', '');
      conn().setConnected();
      expect(
        m.getActiveStrategy(ConnectionStatus.connected),
        isA<InternalAdStrategy>(),
      );

      conn().setAnalyzing(); // DXcore switches method, tunnel stays up.
      expect(
        m.getActiveStrategy(ConnectionStatus.analyzing),
        isA<InternalAdStrategy>(),
      );

      conn().setConnected();
      expect(inHouseAd(), 'https://ads.example/a.png');
    });

    test('a fresh connect shows no leftover in-house ad while analyzing', () {
      container
          .read(adsProvider.notifier)
          .setCustomAdData('https://ads.example/old.png', '');
      conn().setLoading();
      conn().setAnalyzing();
      expect(m.getActiveStrategy(ConnectionStatus.analyzing), isNull);
    });

    test('a disconnect through disconnecting clears the in-house ad', () {
      container
          .read(adsProvider.notifier)
          .setCustomAdData('https://ads.example/a.png', '');
      conn().setConnected();
      conn().setDisconnecting();
      conn().setDisconnected();
      expect(inHouseAd(), isEmpty);
    });
  });

  group('the AdMob ad', () {
    late ProviderContainer container;
    late GoogleAdStrategy strategy;

    void change(ConnectionStatus from, ConnectionStatus to) =>
        strategy.onConnectionStateChanged(
          ref: container.read(_refProvider),
          previous: from,
          current: to,
          hasInitialized: true,
          onRefreshNeeded: () {},
        );

    AdsState ads() => container.read(adsProvider);

    setUp(() {
      container = _container();
      strategy = GoogleAdStrategy(
        backgroundColor: const Color(0xFF19312F),
        cornerRadius: 10,
      );
      addTearDown(strategy.dispose);
    });

    test('shows at the connect tap and stays until disconnect', () {
      GoogleAdStrategy.debugHoldAd(_ad()); // Loaded while disconnected.
      expect(ads().nativeAdIsLoaded, isFalse); // Held, not shown.

      change(ConnectionStatus.disconnected, ConnectionStatus.loading);
      expect(ads().nativeAdIsLoaded, isTrue);
      expect(ads().showCountdown, isTrue);
      expect(ads().countdown, adMobDisplaySeconds);

      change(ConnectionStatus.loading, ConnectionStatus.analyzing);
      change(ConnectionStatus.analyzing, ConnectionStatus.connected);
      expect(ads().nativeAdIsLoaded, isTrue); // Kept after connecting.

      expect(strategy.shownThisConnection, isTrue); // No in-house ad.

      change(ConnectionStatus.connected, ConnectionStatus.disconnected);
      expect(ads().nativeAdIsLoaded, isFalse);
      expect(ads().showCountdown, isFalse);
      expect(strategy.shownThisConnection, isFalse);
    });

    test('after a disconnect another ad shows', () {
      // Connected with no ad at the tap; an ad loaded meanwhile is held.
      change(ConnectionStatus.disconnected, ConnectionStatus.loading);
      change(ConnectionStatus.loading, ConnectionStatus.connected);
      GoogleAdStrategy.debugHoldAd(_ad());

      change(ConnectionStatus.connected, ConnectionStatus.disconnecting);
      expect(ads().nativeAdIsLoaded, isFalse);
      change(ConnectionStatus.disconnecting, ConnectionStatus.disconnected);
      expect(ads().nativeAdIsLoaded, isTrue);
      expect(ads().showCountdown, isTrue);
      expect(strategy.shownThisConnection, isFalse); // Not a connection's ad.
    });

    test('a tap while the post-disconnect ad is up keeps it', () {
      GoogleAdStrategy.debugHoldAd(_ad());
      change(ConnectionStatus.connected, ConnectionStatus.disconnected);
      expect(ads().nativeAdIsLoaded, isTrue);

      change(ConnectionStatus.disconnected, ConnectionStatus.loading);
      expect(ads().nativeAdIsLoaded, isTrue);
      expect(strategy.shownThisConnection, isTrue); // No in-house fallback.
    });

    test('the app starting only holds the ad', () {
      GoogleAdStrategy.debugHoldAd(_ad());
      change(ConnectionStatus.disconnected, ConnectionStatus.disconnected);
      expect(ads().nativeAdIsLoaded, isFalse);
    });

    test('a failed connection removes the tap ad and shows none', () {
      GoogleAdStrategy.debugHoldAd(_ad());
      change(ConnectionStatus.disconnected, ConnectionStatus.loading);
      expect(ads().nativeAdIsLoaded, isTrue);
      change(ConnectionStatus.loading, ConnectionStatus.error);
      expect(ads().nativeAdIsLoaded, isFalse);
    });

    test('the tap after a failed connection shows it too', () {
      GoogleAdStrategy.debugHoldAd(_ad());
      change(ConnectionStatus.error, ConnectionStatus.loading);
      expect(ads().nativeAdIsLoaded, isTrue);
    });

    test('nothing shows when no ad is ready at the tap', () {
      change(ConnectionStatus.disconnected, ConnectionStatus.loading);
      expect(ads().nativeAdIsLoaded, isFalse);
      expect(ads().showCountdown, isFalse);
    });
  });
}
