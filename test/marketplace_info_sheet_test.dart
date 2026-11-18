import 'dart:async';

import 'package:defyx_vpn/common/dtos/subscription_usage_dto.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/settings/models/settings_item.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/marketplace_info_sheet.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_item_widget.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/subscription_usage_ring.dart';
import 'package:defyx_vpn/modules/settings/providers/marketplace_info_provider.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

const _label = 'Premium 1M DE';
const _usageJson = {
  'used_volume_gb': 201,
  'remaining_volume_gb': 99,
  'total_volume_gb': 300,
  'remaining_days': 3,
  'total_days': 60,
  'expire_at': '2026-11-27T18:02:55.918Z',
};

class _FakeMarketplaceInfoService implements MarketplaceInfoService {
  Completer<SubscriptionUsageResponse> usage = Completer();
  Completer<void> jump = Completer();
  final List<String> usageLabels = [];
  final List<String> jumpLabels = [];

  @override
  Future<SubscriptionUsageResponse> getUsage(String label) {
    usageLabels.add(label);
    return usage.future;
  }

  @override
  Future<void> jumpServer(String label) {
    jumpLabels.add(label);
    return jump.future;
  }
}

const _premiumItem = SettingsItem(
  id: 'premium',
  title: _label,
  isEnabled: true,
  isAccessible: true,
  description: 'Defyx Premium Service',
  isPremium: true,
);

void main() {
  group('MarketplaceInfoSheet', () {
    late _FakeMarketplaceInfoService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            const EventChannel('com.defyx.vpn_events'),
            MockStreamHandler.inline(onListen: (_, _) {}),
          );
    });

    Future<ProviderContainer> pumpSettingsRow(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      service = _FakeMarketplaceInfoService();

      final container = ProviderContainer(
        overrides: [marketplaceInfoServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ToastificationWrapper(
            child: ScreenUtilInit(
              designSize: const Size(393, 852),
              builder: (context, child) => MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const Scaffold(
                  body: SettingsItemWidget(item: _premiumItem),
                ),
              ),
            ),
          ),
        ),
      );
      return container;
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(
        find
            .descendant(
              of: find.byType(SettingsItemWidget),
              matching: find.byType(InkWell),
            )
            .last,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> pumpFrames(WidgetTester tester) async {
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> settleToasts(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('premium row opens the sheet and shows shimmer then usage', (
      tester,
    ) async {
      await pumpSettingsRow(tester);
      expect(find.byType(MarketplaceInfoSheet), findsNothing);

      await openSheet(tester);

      expect(find.byType(MarketplaceInfoSheet), findsOneWidget);
      expect(find.text(_label), findsOneWidget);
      expect(
        find.text(
          'This premium subscription was purchased directly from Defyx.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SubscriptionUsageRingShimmer), findsNWidgets(2));
      expect(find.byType(SubscriptionUsageRing), findsNothing);
      expect(service.usageLabels, [_label]);

      service.usage.complete(SubscriptionUsageResponse.fromJson(_usageJson));
      await pumpFrames(tester);

      expect(find.byType(SubscriptionUsageRingShimmer), findsNothing);
      expect(find.byType(SubscriptionUsageRing), findsNWidgets(2));
      expect(find.text('99/300 GB', findRichText: true), findsOneWidget);
      expect(find.text('3/60 DAYS', findRichText: true), findsOneWidget);
      expect(find.text('REMAINING DATA'), findsOneWidget);
      expect(find.text('REMAINING TIME'), findsOneWidget);
      expect(
        find.text('Switch server without changing location.'),
        findsOneWidget,
      );
      expect(find.text('JUMP'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.byType(MarketplaceInfoSheet), findsNothing);
    });

    testWidgets('usage error shows a warning and retry reloads with shimmer', (
      tester,
    ) async {
      await pumpSettingsRow(tester);
      await openSheet(tester);

      service.usage.completeError(Exception('Connection error.'));
      await pumpFrames(tester);

      expect(
        find.text(
          'Could not load your usage. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('--/GB', findRichText: true), findsOneWidget);

      service.usage = Completer();
      await tester.tap(find.text('RETRY'));
      await tester.pump();

      expect(find.byType(SubscriptionUsageRingShimmer), findsNWidgets(2));
      expect(service.usageLabels, [_label, _label]);

      service.usage.complete(SubscriptionUsageResponse.fromJson(_usageJson));
      await pumpFrames(tester);

      expect(find.text('99/300 GB', findRichText: true), findsOneWidget);
      expect(find.text('RETRY'), findsNothing);
    });

    testWidgets('jump runs directly when the VPN is off and reports success', (
      tester,
    ) async {
      await pumpSettingsRow(tester);
      await openSheet(tester);
      service.usage.complete(SubscriptionUsageResponse.fromJson(_usageJson));
      await pumpFrames(tester);

      await tester.tap(find.text('JUMP'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('VPN will be disconnected'), findsNothing);
      expect(service.jumpLabels, [_label]);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('JUMP'), findsNothing);

      service.jump.complete();
      await pumpFrames(tester);

      expect(find.text('JUMP'), findsOneWidget);
      expect(find.text('Server switched successfully.'), findsOneWidget);
      expect(service.usageLabels, [_label, _label]);
      await settleToasts(tester);
    });

    testWidgets('jump failure shows a warning with the reason', (tester) async {
      await pumpSettingsRow(tester);
      await openSheet(tester);
      service.usage.complete(SubscriptionUsageResponse.fromJson(_usageJson));
      await pumpFrames(tester);

      await tester.tap(find.text('JUMP'));
      await tester.pump();
      service.jump.completeError(Exception('No alternative server'));
      await pumpFrames(tester);

      expect(
        find.text('Could not switch server: No alternative server'),
        findsOneWidget,
      );
      expect(find.text('JUMP'), findsOneWidget);
      await settleToasts(tester);
    });

    testWidgets(
      'running VPN asks before jumping and cancel keeps it connected',
      (tester) async {
        final container = await pumpSettingsRow(tester);
        container.read(connectionStateProvider.notifier).setConnected();
        await openSheet(tester);
        service.usage.complete(SubscriptionUsageResponse.fromJson(_usageJson));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('JUMP'));
        await tester.pumpAndSettle();

        expect(find.text('VPN will be disconnected'), findsOneWidget);
        expect(find.text('Yes, switch server'), findsOneWidget);
        expect(service.jumpLabels, isEmpty);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('VPN will be disconnected'), findsNothing);
        expect(service.jumpLabels, isEmpty);
        expect(
          container.read(connectionStateProvider).status,
          ConnectionStatus.connected,
        );
        expect(find.byType(MarketplaceInfoSheet), findsOneWidget);
      },
    );
  });
}
