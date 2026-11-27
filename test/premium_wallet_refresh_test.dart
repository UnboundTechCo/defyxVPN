import 'dart:async';

import 'package:defyx_vpn/modules/premium/presentation/screens/wallet_screen.dart';
import 'package:defyx_vpn/modules/premium/providers/premium_wallet_provider.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.loggedIn);

  final bool loggedIn;

  @override
  Future<AuthData> build() async =>
      AuthData(email: 'user@example.com', isLoggedIn: loggedIn);
}

class _FakeBalanceApi {
  final List<Completer<double>> requests = [];

  Future<double> fetch() {
    final request = Completer<double>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  group('PremiumWalletView refresh button', () {
    late _FakeBalanceApi api;

    Future<void> pumpWallet(WidgetTester tester, {bool loggedIn = true}) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      api = _FakeBalanceApi();

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthNotifier(loggedIn)),
          balanceProvider.overrideWith((ref) => api.fetch()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, child) =>
                const MaterialApp(home: WalletScreen()),
          ),
        ),
      );
      api.requests.single.complete(74.73);
      await tester.pump();
      await tester.pump();
    }

    Finder refreshIcon() => find.byIcon(Icons.refresh);

    AnimationController spinner(WidgetTester tester) {
      final rotation = tester.widget<RotationTransition>(
        find.ancestor(
          of: refreshIcon(),
          matching: find.byType(RotationTransition),
        ),
      );
      return rotation.turns as AnimationController;
    }

    testWidgets('icon is still before the button is tapped', (tester) async {
      await pumpWallet(tester);

      expect(find.text(r'$74.73', findRichText: true), findsOneWidget);
      expect(spinner(tester).isAnimating, isFalse);
      expect(spinner(tester).value, 0);
    });

    testWidgets('icon spins until the balance request completes', (
      tester,
    ) async {
      await pumpWallet(tester);

      await tester.tap(refreshIcon());
      await tester.pump();

      expect(api.requests, hasLength(2));
      expect(spinner(tester).isAnimating, isTrue);

      await tester.pump(const Duration(milliseconds: 200));
      final turnedSoFar = spinner(tester).value;
      expect(turnedSoFar, greaterThan(0));

      await tester.pump(const Duration(milliseconds: 200));
      expect(spinner(tester).value, isNot(turnedSoFar));
      expect(spinner(tester).isAnimating, isTrue);
      expect(find.text(r'$74.73', findRichText: true), findsOneWidget);

      api.requests.last.complete(80.5);
      await tester.pump();
      await tester.pump();

      expect(spinner(tester).isAnimating, isFalse);
      expect(spinner(tester).value, 0);
      expect(find.text(r'$80.50', findRichText: true), findsOneWidget);
    });

    testWidgets('tapping again while spinning sends no extra request', (
      tester,
    ) async {
      await pumpWallet(tester);

      await tester.tap(refreshIcon());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(refreshIcon());
      await tester.pump(const Duration(milliseconds: 100));

      expect(api.requests, hasLength(2));
      expect(spinner(tester).isAnimating, isTrue);

      api.requests.last.complete(74.73);
      await tester.pump();
      await tester.pump();

      expect(spinner(tester).isAnimating, isFalse);

      await tester.tap(refreshIcon());
      await tester.pump();

      expect(api.requests, hasLength(3));
      expect(spinner(tester).isAnimating, isTrue);

      api.requests.last.complete(74.73);
      await tester.pump();
      await tester.pump();
    });

    testWidgets('logged out user gets no spin and no request', (tester) async {
      await pumpWallet(tester, loggedIn: false);

      await tester.tap(refreshIcon());
      await tester.pump(const Duration(milliseconds: 200));

      expect(api.requests, hasLength(1));
      expect(spinner(tester).isAnimating, isFalse);
      expect(spinner(tester).value, 0);
    });
  });
}
