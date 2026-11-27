import 'dart:convert';
import 'dart:io';

import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_interface.dart';
import 'package:defyx_vpn/modules/settings/constants/settings_constants.dart';
import 'package:defyx_vpn/modules/settings/models/country_names.dart';
import 'package:defyx_vpn/modules/settings/models/method_sections.dart';
import 'package:defyx_vpn/modules/settings/models/settings_item.dart';
import 'package:defyx_vpn/modules/settings/providers/settings_provider.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/settings/models/settings_group.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_group_widget.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_item_widget.dart';
import 'package:defyx_vpn/shared/providers/haptics_provider.dart';
import 'package:defyx_vpn/shared/tv/tv_support.dart';
import 'package:defyx_vpn/shared/widgets/defyx_switch.dart';
import 'package:defyx_vpn/shared/widgets/tv_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SettingsItem _item(
  String id, {
  int order = 0,
  bool on = true,
  String? kind,
  bool isPremium = false,
  bool isMarket = false,
  String? planId,
  String? expireAt,
}) => SettingsItem(
  id: id,
  title: id,
  isEnabled: on,
  isAccessible: true,
  sortOrder: order,
  kind: kind,
  isPremium: isPremium,
  isMarket: isMarket,
  planId: planId,
  expireAt: expireAt,
);

String _inDays(int days) =>
    DateTime.now().toUtc().add(Duration(days: days)).toIso8601String();

void main() {
  group('CountryNames', () {
    test('reads ISO codes, the backend\'s plan countries and common names', () {
      expect(CountryNames.of('DE', 'en'), 'Germany');
      expect(CountryNames.of('germany', 'en'), 'Germany');
      expect(CountryNames.of('south_korea', 'en'), 'South Korea');
      expect(CountryNames.of('United States', 'en'), 'United States');
      expect(CountryNames.of('usa', 'en'), 'United States');
      expect(CountryNames.of(' uk ', 'en'), 'United Kingdom');
      expect(CountryNames.of('Holland', 'en'), 'Netherlands');
    });

    test('names them in the app\'s language', () {
      expect(CountryNames.of('NL', 'fa'), 'هلند');
      expect(CountryNames.of('NL', 'ru'), 'Нидерланды');
      expect(CountryNames.of('NL', 'zh'), '荷兰');
      // A language without names falls back to English.
      expect(CountryNames.of('NL', 'de'), 'Netherlands');
    });

    test('knows every country the app has a flag for', () {
      const flags = [
        'at',
        'au',
        'az',
        'be',
        'ca',
        'ch',
        'cz',
        'de',
        'dk',
        'ee',
        'es',
        'fi',
        'fr',
        'gb',
        'hr',
        'hu',
        'in',
        'ir',
        'it',
        'jp',
        'lv',
        'nl',
        'no',
        'pl',
        'pt',
        'ro',
        'rs',
        'ru',
        'se',
        'sg',
        'sk',
        'tr',
        'us',
      ];
      for (final code in flags) {
        for (final language in ['en', 'fa', 'ru', 'zh']) {
          expect(CountryNames.of(code, language), isNotNull, reason: code);
        }
      }
    });

    test('finds each location\'s flag, or the unknown-country flag', () {
      expect(CountryNames.flagAsset('DE'), 'assets/flags/de.svg');
      expect(CountryNames.flagAsset('united_states'), 'assets/flags/us.svg');
      expect(CountryNames.flagAsset('uk'), 'assets/flags/gb.svg');
      // A known country without a flag image, and a city.
      expect(CountryNames.flagAsset('uae'), 'assets/flags/xx.svg');
      expect(CountryNames.flagAsset('Frankfurt'), 'assets/flags/xx.svg');
    });

    test('lists exactly the flags in assets/flags', () {
      final files = {
        for (final file in Directory('assets/flags').listSync())
          file.uri.pathSegments.last.replaceAll('.svg', ''),
      }..remove('xx');
      expect(CountryNames.flagCodes, files);
    });

    test('leaves other locations alone', () {
      expect(CountryNames.of('Frankfurt', 'en'), isNull);
      expect(CountryNames.of('', 'en'), isNull);
    });
  });

  group('MethodSection', () {
    test('comes from kind, and from isPremium/isMarket without one', () {
      expect(_item('a', kind: 'premium').section, MethodSection.premium);
      expect(_item('a', kind: 'market').section, MethodSection.market);
      expect(_item('a', kind: 'builtin').section, MethodSection.builtIn);
      for (final reward in ['invite', 'trial', 'queue', 'gift', 'new_one']) {
        expect(_item('a', kind: reward).section, MethodSection.rewards);
      }
      expect(_item('a', isPremium: true).section, MethodSection.premium);
      expect(_item('a', isMarket: true).section, MethodSection.market);
      expect(_item('a').section, MethodSection.builtIn);
    });
  });

  group('MethodLayout.sections', () {
    test('orders sections and leaves out empty ones', () {
      final sections = MethodLayout.sections([
        _item('reward', order: 0, kind: 'gift'),
        _item('builtin', order: 1),
        _item('premium', order: 2, kind: 'premium'),
      ]);
      expect(
        [for (final s in sections) s.section],
        [MethodSection.premium, MethodSection.builtIn, MethodSection.rewards],
      );
    });

    test('groups a plan\'s locations into one block at its first one', () {
      final sections = MethodLayout.sections([
        _item('solo', order: 0, kind: 'premium'),
        _item('gold de', order: 1, kind: 'premium', planId: 'g'),
        _item('other', order: 2, kind: 'premium', planId: 'x'),
        _item('gold nl', order: 3, kind: 'premium', planId: 'g'),
      ]);
      final blocks = sections.single.blocks;
      expect([for (final b in blocks) b.key], ['solo', 'plan:g', 'other']);
      expect(blocks[1].itemIds, ['gold de', 'gold nl']);
      // A plan with one location is an ordinary row.
      expect(blocks[2].isPlan, isFalse);
    });
  });

  group('MethodLayout.groupPlansByName', () {
    Map<String, SettingsItem> grouped(List<SettingsItem> items) => {
      for (final item in MethodLayout.groupPlansByName(items)) item.id: item,
    };

    test('a plan\'s SOS method names it; its locations join it', () {
      final items = grouped([
        _item('Gold DE', isPremium: true),
        _item('Gold NL', isPremium: true),
        _item('Gold SOS', isPremium: true),
      ]);
      expect({for (final i in items.values) i.planId}, {'name:premium:Gold'});
      expect(items['Gold DE']!.planName, 'Gold');
      expect(items['Gold DE']!.country, 'DE');
      expect(items['Gold SOS']!.isSos, isTrue);
      expect(items['Gold SOS']!.country, isNull);
    });

    test('the longest plan name wins, and locations may have spaces', () {
      final items = grouped([
        _item('Gold Plus United States', isPremium: true),
        _item('Gold Plus SOS', isPremium: true),
        _item('Gold DE', isPremium: true),
        _item('Gold sos', isPremium: true),
      ]);
      expect(items['Gold Plus United States']!.planName, 'Gold Plus');
      expect(items['Gold Plus United States']!.country, 'United States');
      expect(items['Gold DE']!.planName, 'Gold');
    });

    test('a single-location plan groups with its SOS method', () {
      final items = grouped([
        _item('Silver', isMarket: true),
        _item('Silver sos', isMarket: true),
      ]);
      expect(items['Silver']!.planId, 'name:market:Silver');
      expect(items['Silver']!.country, isNull);
      expect(items['Silver sos']!.isSos, isTrue);
    });

    test('finds a plan\'s own config, which stays one of its methods', () {
      final items = MethodLayout.groupPlansByName([
        _item('Silver', isPremium: true),
        _item('Silver sos', isPremium: true),
        _item('Gold DE', isPremium: true),
        _item('Gold SOS', isPremium: true),
      ]);
      final blocks = MethodLayout.sections(items).single.blocks;
      expect(blocks[0].main?.id, 'Silver');
      expect(blocks[0].itemIds, ['Silver', 'Silver sos']);
      expect(blocks[1].main, isNull);
    });

    test('keeps switched-off plans only while they have several methods', () {
      final items = MethodLayout.groupPlansByName([
        _item('Silver', isPremium: true),
        _item('Silver sos', isPremium: true),
      ]);
      expect(
        MethodLayout.liveDisabledPlans(items, ['name:premium:Silver', 'gone']),
        ['name:premium:Silver'],
      );
    });

    test('leaves alone methods without an SOS sibling, built-in methods, '
        'and plans the flowline already names', () {
      final items = grouped([
        _item('Bronze DE', isPremium: true),
        _item('Bronze NL', isPremium: true),
        _item('Warp'),
        _item('Warp SOS'),
        _item('Gold DE', isPremium: true, planId: '7'),
        _item('Gold SOS', isPremium: true, planId: '7'),
      ]);
      expect(items['Bronze DE']!.planId, isNull);
      expect(items['Warp']!.planId, isNull);
      expect(items['Gold DE']!.planId, '7');
      expect(items['Gold DE']!.country, isNull);
    });
  });

  group('MethodLayout.reorderBlocks', () {
    test('moves a plan with its locations and leaves other sections', () {
      final items = MethodLayout.normalize([
        _item('solo', kind: 'premium'),
        _item('gold de', kind: 'premium', planId: 'g'),
        _item('gold nl', kind: 'premium', planId: 'g'),
        _item('builtin'),
      ]);
      final blocks = [
        ['solo'],
        ['gold de', 'gold nl'],
      ];
      final moved = MethodLayout.reorderBlocks(items, blocks, 1, 0);
      final order = [
        for (final item in [
          ...moved,
        ]..sort((a, b) => a.sortOrder!.compareTo(b.sortOrder!)))
          item.id,
      ];
      expect(order, ['gold de', 'gold nl', 'solo', 'builtin']);
    });

    test('returns the same list when nothing moves', () {
      final items = [_item('a', order: 0), _item('b', order: 1)];
      final blocks = [
        ['a'],
        ['b'],
      ];
      expect(
        identical(MethodLayout.reorderBlocks(items, blocks, 0, 0), items),
        isTrue,
      );
      expect(
        identical(MethodLayout.reorderBlocks(items, blocks, 0, 5), items),
        isTrue,
      );
    });
  });

  group('Connection method sections (widget)', () {
    tearDown(() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    });

    final items = MethodLayout.normalize([
      for (final (label, country) in [('Gold DE', 'DE'), ('Gold NL', 'NL')])
        SettingsItem(
          id: label,
          title: label,
          isEnabled: true,
          isAccessible: true,
          kind: 'premium',
          planId: 'g',
          planName: 'Gold',
          country: country,
        ),
      const SettingsItem(
        id: 'Gold SOS',
        title: 'Gold SOS',
        isEnabled: true,
        isAccessible: true,
        kind: 'premium',
        planId: 'g',
        planName: 'Gold',
        isSos: true,
      ),
      SettingsItem(
        id: 'Fast',
        title: 'Fast',
        isEnabled: true,
        isAccessible: true,
        kind: 'market',
        seller: 'NovaNet',
        expireAt: _inDays(9),
      ),
      _item('Alpha'),
      _item('Bravo', on: false),
    ]);

    Future<
      ({
        List<String> plans,
        List<(String, bool)> expansions,
        List<String> toggled,
      })
    >
    pump(
      WidgetTester tester, {
      required FocusNode above,
      List<SettingsItem>? methods,
      List<String> disabledPlans = const [],
      Map<String, bool> expanded = const {},
      Locale? locale,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final plans = <String>[];
      final toggled = <String>[];
      final expansions = <(String, bool)>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hapticsProvider.overrideWith((ref) => HapticsNotifier(prefs)),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, child) => MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      TvFocusable(
                        focusNode: above,
                        onTap: () {},
                        child: const SizedBox(width: 200, height: 40),
                      ),
                      SettingsGroupWidget(
                        group: SettingsGroup(
                          id: 'connection_method',
                          title: 'CONNECTION METHOD',
                          items: methods ?? items,
                          isDraggable: true,
                          disabledPlans: disabledPlans,
                          expanded: expanded,
                        ),
                        onToggle: (groupId, itemId) => toggled.add(itemId),
                        onReorderBlocks: (blocks, from, to) {},
                        onTogglePlan: plans.add,
                        onExpandedChange: (key, expanded) =>
                            expansions.add((key, expanded)),
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
      return (plans: plans, expansions: expansions, toggled: toggled);
    }

    testWidgets('empty sections are hidden; the first section and its only '
        'plan start open, the others closed', (tester) async {
      final above = FocusNode();
      addTearDown(above.dispose);
      final calls = await pump(tester, above: above);

      expect(find.text('PREMIUM'), findsOneWidget);
      expect(find.text('MARKET'), findsOneWidget);
      expect(find.text('BUILT-IN'), findsOneWidget);
      expect(find.text('REWARDS'), findsNothing);
      expect(find.text('3 of 3'), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);

      // The plan shows its locations under its own name, with their flags.
      expect(find.text('GOLD'), findsOneWidget);
      expect(find.text('GERMANY'), findsOneWidget);
      expect(find.text('NETHERLANDS'), findsOneWidget);
      Finder flag(String code) => find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader is SvgAssetLoader &&
            (widget.bytesLoader as SvgAssetLoader).assetName ==
                'assets/flags/$code.svg',
      );
      expect(flag('de'), findsOneWidget);
      expect(flag('nl'), findsOneWidget);
      expect(find.byIcon(Icons.support), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);

      // Market starts closed; opening it shows the seller and days left.
      expect(find.text('FAST'), findsNothing);
      await tester.tap(find.text('MARKET'));
      await tester.pumpAndSettle();
      expect(find.text('FAST'), findsOneWidget);
      // Parts are wrapped in Unicode isolates so mixed scripts keep order.
      expect(
        find.text(
          '\u2068by \u2068NovaNet\u2069\u2069 · \u20689 days left\u2069',
        ),
        findsOneWidget,
      );

      // Tapping the plan closes it; its switch turns the plan off.
      await tester.tap(find.text('GOLD'));
      await tester.pumpAndSettle();
      expect(find.text('GERMANY'), findsNothing);
      await tester.tap(find.byType(DefyxSwitch).first);
      await tester.pumpAndSettle();

      expect(calls.expansions, [('section:market', true), ('plan:g', false)]);
      expect(calls.plans, ['g']);
    });

    testWidgets('a plan\'s own config is listed as its subscription link, '
        'with its own switch', (tester) async {
      final above = FocusNode();
      addTearDown(above.dispose);
      final calls = await pump(
        tester,
        above: above,
        methods: MethodLayout.normalize(
          MethodLayout.groupPlansByName([
            _item('Silver', isPremium: true),
            _item('Silver sos', isPremium: true),
            _item('Warp'),
          ]),
        ),
      );

      // Silver is the only plan in Premium, so it starts open. Its name isn't
      // repeated under it.
      expect(find.text('SILVER'), findsOneWidget);
      expect(find.text('SUBSCRIPTION'), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);

      // The plan's switch turns the plan off; the link's switch only the link.
      await tester.tap(find.byType(DefyxSwitch).at(0));
      await tester.pumpAndSettle();
      expect(calls.plans, ['name:premium:Silver']);
      await tester.tap(find.byType(DefyxSwitch).at(1));
      await tester.pumpAndSettle();
      expect(calls.toggled, ['Silver']);
    });

    testWidgets('while a plan is off, the rows under it show off and can\'t '
        'be switched', (tester) async {
      final above = FocusNode();
      addTearDown(above.dispose);
      final calls = await pump(
        tester,
        above: above,
        methods: MethodLayout.normalize(
          MethodLayout.groupPlansByName([
            _item('Silver', isPremium: true),
            _item('Silver sos', isPremium: true),
            _item('Warp'),
          ]),
        ),
        disabledPlans: const ['name:premium:Silver'],
      );

      final switches = tester
          .widgetList<DefyxSwitch>(find.byType(DefyxSwitch))
          .toList();
      expect(switches[0].value, isFalse); // the plan
      // Its subscription link and SOS, both saved as on.
      for (final row in switches.sublist(1, 3)) {
        expect(row.value, isFalse);
        expect(row.enabled, isFalse);
      }

      await tester.tap(find.text('SUBSCRIPTION'));
      await tester.tap(find.text('SOS'));
      await tester.tap(find.byType(DefyxSwitch).at(2));
      await tester.pumpAndSettle();
      expect(calls.toggled, isEmpty);
    });

    testWidgets('a user with only the free methods sees them open, even if '
        'they once closed them', (tester) async {
      final above = FocusNode();
      addTearDown(above.dispose);
      await pump(
        tester,
        above: above,
        methods: MethodLayout.normalize([_item('Warp'), _item('Psiphon')]),
        expanded: const {'section:builtIn': false},
      );
      expect(find.text('BUILT-IN'), findsOneWidget);
      expect(find.text('WARP'), findsOneWidget);
      expect(find.text('PSIPHON'), findsOneWidget);
    });

    testWidgets('with paid sections above, a closed Built-in stays closed', (
      tester,
    ) async {
      final above = FocusNode();
      addTearDown(above.dispose);
      await pump(
        tester,
        above: above,
        methods: MethodLayout.normalize([
          _item('Gold', isPremium: true),
          _item('Warp'),
        ]),
        expanded: const {'section:builtIn': false},
      );
      expect(find.text('GOLD'), findsOneWidget);
      expect(find.text('WARP'), findsNothing);
    });

    testWidgets('long location and plan names end in "..." after 20 '
        'characters', (tester) async {
      final above = FocusNode();
      addTearDown(above.dispose);
      await pump(
        tester,
        above: above,
        methods: MethodLayout.normalize(
          MethodLayout.groupPlansByName([
            _item(
              'Platinum Unlimited Pro Frankfurt Am Main Datacenter',
              isPremium: true,
            ),
            _item('Platinum Unlimited Pro SOS', isPremium: true),
          ]),
        ),
      );
      // Cut titles are wrapped in a Unicode isolate for right-to-left text.
      expect(find.text('\u2068PLATINUM UNLIMITED P...\u2069'), findsOneWidget);
      expect(find.text('\u2068FRANKFURT AM MAIN DA...\u2069'), findsOneWidget);
    });

    testWidgets('in Persian, rows run right to left: handle, flag and name '
        'on the right, switch on the left', (tester) async {
      final above = FocusNode();
      addTearDown(above.dispose);
      await pump(
        tester,
        above: above,
        locale: const Locale('fa'),
        methods: MethodLayout.normalize(
          MethodLayout.groupPlansByName([
            _item('Gold DE', isPremium: true),
            _item('Gold SOS', isPremium: true),
          ]),
        ),
      );

      final name = tester.getCenter(find.text('آلمان'));
      final flag = tester.getCenter(
        find.byWidgetPredicate(
          (widget) =>
              widget is SvgPicture &&
              widget.bytesLoader is SvgAssetLoader &&
              (widget.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/flags/de.svg',
        ),
      );
      final row = find.ancestor(
        of: find.text('آلمان'),
        matching: find.byType(SettingsItemWidget),
      );
      final handle = tester.getCenter(
        find.descendant(
          of: row,
          matching: find.byType(ReorderableDragStartListener),
        ),
      );
      final toggle = tester.getCenter(
        find.descendant(of: row, matching: find.byType(DefyxSwitch)),
      );
      expect(handle.dx, greaterThan(flag.dx));
      expect(flag.dx, greaterThan(name.dx));
      expect(name.dx, greaterThan(toggle.dx));

      // The section header too: title on the right, count and chevron left.
      expect(
        tester.getCenter(find.text('پریمیوم')).dx,
        greaterThan(tester.getCenter(find.text('2 از 2')).dx),
      );
    });

    testWidgets('badges follow the section: a reward the backend marks '
        'isMarket gets none', (tester) async {
      final above = FocusNode();
      addTearDown(above.dispose);
      await pump(
        tester,
        above: above,
        methods: MethodLayout.normalize([
          const SettingsItem(
            id: 'Fast',
            title: 'Fast',
            isEnabled: true,
            isAccessible: true,
            isMarket: true,
            kind: 'market',
          ),
          const SettingsItem(
            id: 'Welcome',
            title: 'Welcome',
            isEnabled: true,
            isAccessible: true,
            isMarket: true,
            kind: 'free_trial',
          ),
        ]),
        expanded: const {'section:rewards': true},
      );
      Finder badge(String path) => find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader is SvgAssetLoader &&
            (widget.bytesLoader as SvgAssetLoader).assetName == path,
      );
      expect(find.text('WELCOME'), findsOneWidget);
      // Only the market config has the market badge.
      expect(badge('assets/icons/market.svg'), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('WELCOME'),
            matching: find.byType(SettingsItemWidget),
          ),
          matching: badge('assets/icons/market.svg'),
        ),
        findsNothing,
      );
    });

    testWidgets('each premium location keeps its usage icon; SOS and market '
        'locations have none', (tester) async {
      final above = FocusNode();
      addTearDown(above.dispose);
      await pump(
        tester,
        above: above,
        methods: MethodLayout.normalize(
          MethodLayout.groupPlansByName([
            _item('Gold DE', isPremium: true),
            _item('Gold NL', isPremium: true),
            _item('Gold SOS', isPremium: true),
            _item('Fast TR', isMarket: true),
            _item('Fast SOS', isMarket: true),
          ]),
        ),
        expanded: const {
          'section:market': true,
          'plan:name:premium:Gold': true,
          'plan:name:market:Fast': true,
        },
      );

      Finder usageIcon(String rowTitle, {int row = 0}) => find.descendant(
        of: find
            .ancestor(
              of: find.text(rowTitle),
              matching: find.byType(SettingsItemWidget),
            )
            .at(row),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SvgPicture &&
              widget.bytesLoader is SvgAssetLoader &&
              (widget.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icons/info.svg',
        ),
      );

      expect(usageIcon('GERMANY'), findsOneWidget);
      expect(usageIcon('NETHERLANDS'), findsOneWidget);
      expect(find.text('SOS'), findsNWidgets(2));
      expect(usageIcon('SOS', row: 0), findsNothing);
      expect(usageIcon('TURKEY'), findsNothing);
      expect(usageIcon('SOS', row: 1), findsNothing);
    });

    testWidgets('TV: OK opens and closes; Right reaches the plan switch', (
      tester,
    ) async {
      TvSupport.debugIsTv = true;
      addTearDown(() => TvSupport.debugIsTv = false);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      final above = FocusNode();
      addTearDown(above.dispose);
      final calls = await pump(tester, above: above);

      FocusNode rowFocus(String text) =>
          Focus.of(tester.element(find.text(text)));
      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
      }

      above.requestFocus();
      await tester.pumpAndSettle();
      await press(LogicalKeyboardKey.arrowDown);
      expect(rowFocus('PREMIUM').hasPrimaryFocus, isTrue);
      await press(LogicalKeyboardKey.arrowDown);
      expect(rowFocus('GOLD').hasPrimaryFocus, isTrue);

      // Right moves to the plan's switch; OK there turns the plan off.
      await press(LogicalKeyboardKey.arrowRight);
      expect(rowFocus('GOLD').hasPrimaryFocus, isFalse);
      await press(LogicalKeyboardKey.select);
      expect(calls.plans, ['g']);
      expect(calls.expansions, isEmpty);

      // Back on the row, OK closes the plan.
      await press(LogicalKeyboardKey.arrowLeft);
      expect(rowFocus('GOLD').hasPrimaryFocus, isTrue);
      await press(LogicalKeyboardKey.select);
      expect(find.text('GERMANY'), findsNothing);
      expect(calls.expansions, [('plan:g', false)]);
    });
  });

  group('SettingsNotifier', () {
    late _FakeSecureStorage storage;
    late ProviderContainer container;

    Future<SettingsNotifier> start({
      required List<Map<String, dynamic>> flowline,
      List<SettingsItem>? saved,
    }) async {
      storage.values[flowLineKey] = jsonEncode(flowline);
      if (saved != null) {
        storage.values[SettingsStorageKey.appSettings] = jsonEncode({
          SettingsGroupId.connectionMethod: {
            'id': SettingsGroupId.connectionMethod,
            'title': 'CONNECTION METHOD',
            'isDraggable': true,
            // Saved by the app before sections: no kind, plan or dates.
            'items': [
              for (final item in saved)
                {
                  'id': item.id,
                  'title': item.title,
                  'isEnabled': item.isEnabled,
                  'isAccessible': true,
                  'sortOrder': item.sortOrder,
                  'itemType': 'toggle',
                  'isPremium': item.isPremium,
                  'isMarket': item.isMarket,
                },
            ],
          },
        });
      }
      container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(settingsProvider.notifier);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      return notifier;
    }

    List<String> sectionOrder() {
      final group = container
          .read(settingsProvider)
          .groups[SettingsGroupId.connectionMethod]!;
      return [
        for (final section in MethodLayout.sections(group.items))
          for (final item in section.items) item.title,
      ];
    }

    setUp(() => storage = _FakeSecureStorage());

    test('an old saved list keeps its order inside sections; new methods '
        'go to theirs', () async {
      final notifier = await start(
        saved: [
          _item('B', order: 0),
          _item('P', order: 1, isPremium: true),
          _item('A', order: 2, on: false),
        ],
        flowline: [
          {'label': 'P', 'kind': 'premium', 'enabled': true},
          {
            'label': 'M',
            'kind': 'market',
            'seller': 'NovaNet',
            'enabled': true,
          },
          {
            'label': 'G',
            'kind': 'gift',
            'expireAt': _inDays(5),
            'enabled': true,
          },
          {
            'label': 'I',
            'kind': 'invite',
            'expire_at': _inDays(2),
            'enabled': true,
          },
          {'label': 'A', 'enabled': true},
          {'label': 'B', 'enabled': true},
        ],
      );

      expect(sectionOrder(), ['P', 'M', 'B', 'A', 'I', 'G']);
      // A stays off: the user's switch wins over the flowline's default.
      expect(notifier.getConnectionMethodPattern(), 'P,M,B,I,G');
    });

    test(
      'a plan switch turns its locations off and back on as they were',
      () async {
        final notifier = await start(
          flowline: [
            for (final (label, country) in [
              ('Gold DE', 'DE'),
              ('Gold NL', 'NL'),
            ])
              {
                'label': label,
                'kind': 'premium',
                'planId': 7,
                'planName': 'Gold',
                'country': country,
                'enabled': true,
              },
            {
              'label': 'Gold SOS',
              'kind': 'premium',
              'planId': 7,
              'sos': true,
              'enabled': true,
            },
            {'label': 'Builtin', 'enabled': true},
          ],
        );
        final id = container
            .read(settingsProvider)
            .groups[SettingsGroupId.connectionMethod]!
            .items
            .firstWhere((item) => item.title == 'Gold NL')
            .id;
        notifier.toggleSetting(SettingsGroupId.connectionMethod, id);
        expect(
          notifier.getConnectionMethodPattern(),
          'Gold DE,Gold SOS,Builtin',
        );

        notifier.togglePlan(SettingsGroupId.connectionMethod, '7');
        expect(notifier.getConnectionMethodPattern(), 'Builtin');

        notifier.togglePlan(SettingsGroupId.connectionMethod, '7');
        expect(
          notifier.getConnectionMethodPattern(),
          'Gold DE,Gold SOS,Builtin',
        );
      },
    );

    test(
      'the plan switch can\'t turn off the last methods that are on',
      () async {
        final notifier = await start(
          flowline: [
            {
              'label': 'Gold DE',
              'kind': 'premium',
              'planId': 'g',
              'enabled': true,
            },
            {
              'label': 'Gold NL',
              'kind': 'premium',
              'planId': 'g',
              'enabled': true,
            },
            {'label': 'Builtin', 'enabled': false},
          ],
        );
        notifier.togglePlan(SettingsGroupId.connectionMethod, 'g');
        expect(notifier.getConnectionMethodPattern(), 'Gold DE,Gold NL');
      },
    );

    test('turning a plan off leaves out all of its methods; back on, they '
        'follow their own switches', () async {
      final notifier = await start(
        flowline: [
          {'label': 'Silver', 'isPremium': true, 'enabled': true},
          {'label': 'Silver sos', 'isPremium': true, 'enabled': true},
          {'label': 'Warp', 'enabled': true},
        ],
      );
      SettingsItem method(String title) => container
          .read(settingsProvider)
          .groups[SettingsGroupId.connectionMethod]!
          .items
          .firstWhere((item) => item.title == title);

      // The plan's own config has its own switch.
      notifier.toggleSetting(
        SettingsGroupId.connectionMethod,
        method('Silver').id,
      );
      expect(notifier.getConnectionMethodPattern(), 'Silver sos,Warp');

      notifier.togglePlan(
        SettingsGroupId.connectionMethod,
        'name:premium:Silver',
      );
      expect(notifier.getConnectionMethodPattern(), 'Warp');

      // While the plan is off, its methods can't be switched.
      notifier.toggleSetting(
        SettingsGroupId.connectionMethod,
        method('Silver').id,
      );
      expect(method('Silver').isEnabled, isFalse);

      notifier.togglePlan(
        SettingsGroupId.connectionMethod,
        'name:premium:Silver',
      );
      expect(notifier.getConnectionMethodPattern(), 'Silver sos,Warp');
    });

    test(
      'a list saved with "Silver" off and its SOS on stays that way',
      () async {
        final notifier = await start(
          saved: [
            _item('Silver', order: 0, isPremium: true, on: false),
            _item('Silver sos', order: 1, isPremium: true),
            _item('Warp', order: 2),
          ],
          flowline: [
            {'label': 'Silver', 'isPremium': true, 'enabled': true},
            {'label': 'Silver sos', 'isPremium': true, 'enabled': true},
            {'label': 'Warp', 'enabled': true},
          ],
        );
        expect(notifier.getConnectionMethodPattern(), 'Silver sos,Warp');
      },
    );

    test('an expired reward is left out and can\'t be switched', () async {
      final notifier = await start(
        flowline: [
          {
            'label': 'Old',
            'kind': 'gift',
            'expireAt': _inDays(-1),
            'enabled': true,
          },
          {'label': 'Builtin', 'enabled': true},
        ],
      );
      expect(notifier.getConnectionMethodPattern(), 'Builtin');

      final old = container
          .read(settingsProvider)
          .groups[SettingsGroupId.connectionMethod]!
          .items
          .firstWhere((item) => item.title == 'Old');
      notifier.toggleSetting(SettingsGroupId.connectionMethod, old.id);
      final after = container
          .read(settingsProvider)
          .groups[SettingsGroupId.connectionMethod]!
          .items
          .firstWhere((item) => item.title == 'Old');
      expect(after.isEnabled, isTrue);
    });

    test(
      'a new location joins a plan found by name, which stays put',
      () async {
        await start(
          saved: [
            _item('Solo', order: 0, isPremium: true),
            _item('Gold DE', order: 1, isPremium: true),
            _item('Gold SOS', order: 2, isPremium: true),
            _item('Warp', order: 3),
          ],
          flowline: [
            {'label': 'Solo', 'isPremium': true, 'enabled': true},
            {'label': 'Gold DE', 'isPremium': true, 'enabled': true},
            {'label': 'Gold NL', 'isPremium': true, 'enabled': true},
            {'label': 'Gold SOS', 'isPremium': true, 'enabled': true},
            {'label': 'Warp', 'enabled': true},
          ],
        );
        expect(sectionOrder(), [
          'Solo',
          'Gold DE',
          'Gold SOS',
          'Gold NL',
          'Warp',
        ]);
        final group = container
            .read(settingsProvider)
            .groups[SettingsGroupId.connectionMethod]!;
        final blocks = MethodLayout.sections(group.items).first.blocks;
        expect(
          [for (final b in blocks) b.key],
          ['Solo', 'plan:name:premium:Gold'],
        );
      },
    );

    test('a new location of a plan joins it instead of moving it', () async {
      Map<String, dynamic> gold(String label) => {
        'label': label,
        'kind': 'premium',
        'planId': 'g',
        'enabled': true,
      };
      await start(
        saved: [
          _item('Solo', order: 0, isPremium: true),
          _item('Gold DE', order: 1, isPremium: true),
          _item('Gold NL', order: 2, isPremium: true),
        ],
        flowline: [
          {'label': 'Solo', 'kind': 'premium', 'enabled': true},
          gold('Gold DE'),
          gold('Gold NL'),
          gold('Gold TR'),
        ],
      );
      expect(sectionOrder(), ['Solo', 'Gold DE', 'Gold NL', 'Gold TR']);
    });
  });
}

class _FakeSecureStorage implements ISecureStorage {
  final Map<String, String> values = {};

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> writeMap(String key, Map<String, dynamic> map) async =>
      values[key] = jsonEncode(map);

  @override
  Future<Map<String, dynamic>> readMap(String key) async =>
      jsonDecode(values[key] ?? '{}') as Map<String, dynamic>;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async => values.remove(key);
}
