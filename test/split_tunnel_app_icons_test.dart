import 'dart:convert';
import 'dart:io';

import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/settings/models/installed_app.dart';
import 'package:defyx_vpn/modules/settings/models/popular_app.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/split_tunnel_installed_apps_list.dart';
import 'package:defyx_vpn/modules/settings/providers/split_tunnel_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

Future<void> _pumpList(
  WidgetTester tester,
  List<InstalledApp> apps,
  List<String> requested,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        installedAppsProvider.overrideWith((ref) async => apps),
        appIconProvider.overrideWith((ref, packageName) async {
          requested.add(packageName);
          return _png;
        }),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomScrollView(
              slivers: [SplitTunnelInstalledAppsList(query: '')],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('icons load only for the rows on screen', (tester) async {
    tester.view.physicalSize = const Size(393, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final apps = [
      for (var i = 0; i < 40; i++)
        InstalledApp(name: 'App $i', packageName: 'com.example.app$i'),
    ];
    final requested = <String>[];
    await _pumpList(tester, apps, requested);

    expect(requested, isNotEmpty);
    expect(requested.length, lessThan(apps.length));
    expect(requested, contains('com.example.app0'));
    expect(find.byType(Image), findsWidgets);

    final firstScreen = requested.length;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(requested.length, greaterThan(firstScreen));
    expect(requested.toSet().length, requested.length);
  });

  testWidgets('apps with their own icon never ask for one', (tester) async {
    final apps = [
      for (final app in popularApps.take(5))
        InstalledApp(
          name: app.name,
          packageName: app.id,
          iconSvg: File(app.iconAsset).readAsBytesSync(),
        ),
    ];
    final requested = <String>[];
    await _pumpList(tester, apps, requested);

    expect(find.text('Telegram'), findsOneWidget);
    expect(requested, isEmpty);
  });
}
