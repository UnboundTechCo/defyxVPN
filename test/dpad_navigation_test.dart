// D-pad (TV remote) navigation tests for the Android TV "Missing DPad
// functionality" fixes.

import 'package:defyx_vpn/app/router/dpad_shell_page.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/settings/models/settings_group.dart';
import 'package:defyx_vpn/modules/settings/models/settings_item.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_group_widget.dart';
import 'package:defyx_vpn/shared/providers/haptics_provider.dart';
import 'package:defyx_vpn/shared/tv/tv_support.dart';
import 'package:defyx_vpn/shared/widgets/dpad_text_field_scope.dart';
import 'package:defyx_vpn/shared/widgets/tv_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

Widget _box({double width = 200, double height = 40}) =>
    SizedBox(width: width, height: height);

void main() {
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('TvFocusable', () {
    testWidgets('OK activates once; key repeats and key up are swallowed', (
      tester,
    ) async {
      var taps = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        _app(TvFocusable(focusNode: node, onTap: () => taps++, child: _box())),
      );
      node.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      expect(taps, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
      expect(taps, 3);
    });

    testWidgets('holding OK calls onSelectLongPress instead of onTap', (
      tester,
    ) async {
      var taps = 0;
      var longPresses = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        _app(
          TvFocusable(
            focusNode: node,
            onTap: () => taps++,
            onSelectLongPress: () => longPresses++,
            child: _box(),
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      expect(longPresses, 1);
      expect(taps, 0);

      // A short press still taps, on key up.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 100));
      expect(taps, 0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      expect(taps, 1);
      expect(longPresses, 1);

      // Android's own long-press signal: the held key starts repeating.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      expect(longPresses, 2);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 600));
      expect(longPresses, 2);
      expect(taps, 1);
    });

    testWidgets('the focus ring only shows for remote/keyboard focus', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        _app(TvFocusable(focusNode: node, onTap: () {}, child: _box())),
      );
      node.requestFocus();
      await tester.pump();

      double ringOpacity() => tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: find.byType(TvFocusable),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;

      expect(ringOpacity(), 0);

      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await tester.pump();
      expect(ringOpacity(), 1);

      node.unfocus();
      await tester.pump();
      expect(ringOpacity(), 0);
    });
  });

  testWidgets('TvFocusRing shows while the wrapped InkWell has focus', (
    tester,
  ) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      _app(
        TvFocusRing(
          child: InkWell(focusNode: node, onTap: () {}, child: _box()),
        ),
      ),
    );

    double ringOpacity() => tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(TvFocusRing),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    expect(ringOpacity(), 0);
    node.requestFocus();
    await tester.pump();
    expect(ringOpacity(), 1);
    node.unfocus();
    await tester.pump();
    expect(ringOpacity(), 0);
  });

  testWidgets('DpadTextFieldScope: Up/Down move focus out of a text field', (
    tester,
  ) async {
    TvSupport.debugIsTv = true;
    addTearDown(() => TvSupport.debugIsTv = false);
    final above = FocusNode();
    final field = FocusNode();
    final below = FocusNode();
    addTearDown(above.dispose);
    addTearDown(field.dispose);
    addTearDown(below.dispose);

    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TvFocusable(focusNode: above, onTap: () {}, child: _box()),
            DpadTextFieldScope(
              child: SizedBox(width: 200, child: TextField(focusNode: field)),
            ),
            TvFocusable(focusNode: below, onTap: () {}, child: _box()),
          ],
        ),
      ),
    );

    field.requestFocus();
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'example.com');
    await tester.pump();

    // Without the scope the field would keep these keys for the caret.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(below.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(field.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(above.hasPrimaryFocus, isTrue);
  });

  testWidgets('DpadTextFieldScope: a field is not skipped when the control '
      'above does not line up with its editable area', (tester) async {
    TvSupport.debugIsTv = true;
    addTearDown(() => TvSupport.debugIsTv = false);
    final back = FocusNode(debugLabel: 'back');
    final field = FocusNode(debugLabel: 'field');
    final login = FocusNode(debugLabel: 'login');
    for (final node in [back, field, login]) {
      addTearDown(node.dispose);
    }

    // Like the Premium login: a small back button on the left, then a field
    // whose editable area starts after a prefix icon, then a wide button.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TvFocusable(
                  focusNode: back,
                  onTap: () {},
                  child: _box(width: 40, height: 40),
                ),
              ),
              DpadTextFieldScope(
                child: TextField(
                  focusNode: field,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.mail),
                  ),
                ),
              ),
              TvFocusable(focusNode: login, onTap: () {}, child: _box()),
            ],
          ),
        ),
      ),
    );

    back.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(field.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(login.hasPrimaryFocus, isTrue);
  });

  group('DpadShellPage', () {
    late FocusNode nav;
    late FocusNode aTop;
    late FocusNode aBottom;
    late FocusNode bTop;
    late GoRouter router;

    Page<void> page(GoRouterState state, Widget child) => DpadShellPage<void>(
      key: state.pageKey,
      transitionsBuilder: (context, animation, secondary, child) => child,
      child: Material(child: child),
    );

    /// A shell like the app's: pages fill it and a nav bar floats on top.
    Future<void> pumpShell(WidgetTester tester) async {
      nav = FocusNode(debugLabel: 'nav');
      aTop = FocusNode(debugLabel: 'aTop');
      aBottom = FocusNode(debugLabel: 'aBottom');
      bTop = FocusNode(debugLabel: 'bTop');
      for (final node in [nav, aTop, aBottom, bTop]) {
        addTearDown(node.dispose);
      }
      router = GoRouter(
        initialLocation: '/a',
        routes: [
          ShellRoute(
            builder: (context, state, child) => Scaffold(
              body: Stack(
                children: [
                  child,
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Center(
                      child: TvFocusable(
                        focusNode: nav,
                        onTap: () {},
                        child: _box(width: 60, height: 60),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            routes: [
              GoRoute(
                path: '/a',
                pageBuilder: (context, state) => page(
                  state,
                  Column(
                    children: [
                      TvFocusable(focusNode: aTop, onTap: () {}, child: _box()),
                      const Spacer(),
                      TvFocusable(
                        focusNode: aBottom,
                        onTap: () {},
                        child: _box(),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
              GoRoute(
                path: '/b',
                pageBuilder: (context, state) => page(
                  state,
                  Align(
                    alignment: Alignment.topCenter,
                    child: TvFocusable(
                      focusNode: bTop,
                      onTap: () {},
                      child: _box(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
    }

    testWidgets('Down from the bottom of a page reaches the nav bar', (
      tester,
    ) async {
      await pumpShell(tester);

      aTop.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(aBottom.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(nav.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(aBottom.hasPrimaryFocus, isTrue);
    });

    testWidgets('Down from a control near the top of a page reaches the nav '
        'bar (like the connect button on Home)', (tester) async {
      await pumpShell(tester);
      router.go('/b');
      await tester.pumpAndSettle();

      bTop.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(nav.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(bTop.hasPrimaryFocus, isTrue);
    });

    testWidgets('focus never lands on a page covered by a pushed page', (
      tester,
    ) async {
      await pumpShell(tester);
      aBottom.requestFocus();
      await tester.pump();

      router.push('/b');
      await tester.pumpAndSettle();
      bTop.requestFocus();
      await tester.pump();

      // The hidden page A sits between B's button and the nav bar.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(nav.hasPrimaryFocus, isTrue);
      expect(aBottom.hasFocus, isFalse);

      // Page A gets its focus back once it is visible again.
      router.pop();
      await tester.pumpAndSettle();
      expect(aBottom.hasPrimaryFocus, isTrue);
    });
  });

  group('Settings connection methods', () {
    SettingsItem item(String name, int order) => SettingsItem(
      id: name,
      title: name,
      isEnabled: true,
      isAccessible: true,
      sortOrder: order,
      description: 'About $name',
    );

    List<SettingsItem> reorder(List<SettingsItem> items, int from, int to) {
      final sorted = [...items]
        ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
      if (to > from) to -= 1;
      final moved = sorted.removeAt(from);
      sorted.insert(to, moved);
      return [
        for (var i = 0; i < sorted.length; i++)
          sorted[i].copyWith(sortOrder: i),
      ];
    }

    /// Runs the connection-method list the way the Settings page shows it:
    /// inside the page's scroll view, with other controls above and below.
    Future<void> exerciseConnectionMethods(
      WidgetTester tester, {
      required bool tv,
    }) async {
      TvSupport.debugIsTv = tv;
      addTearDown(() => TvSupport.debugIsTv = false);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;

      final above = FocusNode(debugLabel: 'above');
      final below = FocusNode(debugLabel: 'below');
      addTearDown(above.dispose);
      addTearDown(below.dispose);
      final toggled = <String>[];
      final reorders = <(int, int)>[];
      var items = [item('alpha', 0), item('bravo', 1), item('charlie', 2)];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hapticsProvider.overrideWith((ref) => HapticsNotifier(prefs)),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, child) => MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      TvFocusable(
                        focusNode: above,
                        onTap: () {},
                        child: _box(),
                      ),
                      StatefulBuilder(
                        builder: (context, setState) => SettingsGroupWidget(
                          group: SettingsGroup(
                            id: 'connection_method',
                            title: 'CONNECTION METHOD',
                            items: items,
                            isDraggable: true,
                          ),
                          onToggle: (groupId, itemId) => toggled.add(itemId),
                          onReorder: (from, to) {
                            reorders.add((from, to));
                            setState(() => items = reorder(items, from, to));
                          },
                        ),
                      ),
                      TvFocusable(
                        focusNode: below,
                        onTap: () {},
                        child: _box(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      FocusNode rowFocus(String title) =>
          Focus.of(tester.element(find.text(title)));

      if (tv) {
        // Entering from above must land on the list, not skip past it.
        above.requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(rowFocus('ALPHA').hasPrimaryFocus, isTrue);
      } else {
        rowFocus('ALPHA').requestFocus();
        await tester.pumpAndSettle();
      }
      expect(find.text('About alpha'), findsOneWidget);
      expect(find.text('Hold OK to reorder'), findsOneWidget);

      // Short OK press toggles the method.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      expect(toggled, ['alpha']);

      // Holding OK starts the move mode.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.text('▲ ▼ to move · OK to finish'), findsOneWidget);

      // Down moves it below BRAVO; focus stays on the moved row.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(reorders, [(0, 2)]);
      expect(
        tester.getTopLeft(find.text('BRAVO')).dy,
        lessThan(tester.getTopLeft(find.text('ALPHA')).dy),
      );
      expect(rowFocus('ALPHA').hasPrimaryFocus, isTrue);

      // OK ends the move mode without toggling.
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.text('Hold OK to reorder'), findsOneWidget);
      expect(toggled, ['alpha']);

      // Down navigates again instead of moving.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(reorders, [(0, 2)]);
      expect(rowFocus('CHARLIE').hasPrimaryFocus, isTrue);

      if (tv) {
        // ...and leaves the list at its end.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(below.hasPrimaryFocus, isTrue);
      }
    }

    testWidgets('TV: the list is reachable; OK toggles; hold OK, then Down '
        'moves the method and keeps focus on it', (tester) async {
      await exerciseConnectionMethods(tester, tv: true);
    });

    testWidgets('touch layout (ReorderableListView): the D-pad move mode '
        'keeps focus on the moved row', (tester) async {
      await exerciseConnectionMethods(tester, tv: false);
    });
  });
}
