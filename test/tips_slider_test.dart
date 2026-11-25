// Tips card: its height fits the tip on screen, including after the card is
// hidden and shown again (connect, then disconnect) and after swipes.

import 'dart:io';

import 'package:defyx_vpn/common/dtos/hint.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/tips_widget.dart';
import 'package:defyx_vpn/shared/providers/hints_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const _tips = [
  Hint(title: 'Short', message: 'One line.'),
  Hint(
    title: 'Long',
    message:
        'This tip is much longer than the others so that it needs several '
        'lines of text inside the card, which makes the card grow taller '
        'to fit it, and shrink again for the short tips around it.',
  ),
  Hint(title: null, message: 'Two lines of text here, no title on this tip.'),
];

Widget _host({required bool showTips}) => ScreenUtilInit(
  designSize: const Size(393, 852),
  builder: (_, _) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Stack(
        children: [
          const SizedBox.expand(),
          if (showTips)
            const Positioned(
              left: 24,
              right: 24,
              bottom: 150,
              child: TipsSlider(),
            ),
        ],
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    // Real glyph metrics, so the measured text heights are realistic.
    final lato = FontLoader('Lato');
    for (final file in [
      'assets/fonts/Lato-Regular.ttf',
      'assets/fonts/Lato-Bold.ttf',
    ]) {
      final bytes = File(file).readAsBytesSync();
      lato.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await lato.load();
  });

  testWidgets('the card fits the tip on screen through swipes and '
      'hide/show', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [selectedHintsProvider.overrideWith((ref) async => _tips)],
    );
    addTearDown(container.dispose);

    Future<void> show(bool showTips) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _host(showTips: showTips),
        ),
      );
      await settle(tester);
    }

    Future<void> swipe() async {
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await settle(tester);
    }

    void expectFits(String step) {
      final pageView = tester.widget<PageView>(find.byType(PageView));
      final shown = pageView.controller!.page!.round();
      final viewport = tester.getRect(find.byType(PageView));
      final text = tester.getRect(find.text(_tips[shown].message));
      final card = tester.getRect(find.byType(AnimatedContainer));
      // Not cut off at the bottom...
      expect(
        text.bottom,
        lessThanOrEqualTo(viewport.bottom + 0.5),
        reason: step,
      );
      // ...and not sized for a taller tip (the 120 minimum aside).
      if (card.height > 120.5) {
        expect(text.bottom, closeTo(viewport.bottom, 1), reason: step);
      }
    }

    await show(true);
    expectFits('first show');
    await swipe();
    expectFits('swiped to the long tip');
    await swipe();
    expectFits('swiped to the third tip');

    await show(false); // Connected: no tips.
    await show(true); // Disconnected again.
    expectFits('shown again after being hidden');
    await swipe();
    expectFits('swiped after being shown again');

    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
