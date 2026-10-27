import 'dart:convert';
import 'dart:io';

import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/settings/models/installed_app.dart';
import 'package:defyx_vpn/modules/settings/models/popular_app.dart';
import 'package:defyx_vpn/modules/settings/models/split_tunnel_config.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/split_tunnel_installed_apps_list.dart';
import 'package:defyx_vpn/modules/settings/providers/split_tunnel_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

final _domainPattern = RegExp(r'^[a-z0-9_-]+(\.[a-z0-9_-]+)*$');

void main() {
  test('popular apps are complete', () {
    final ids = popularApps.map((app) => app.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/icons/apps/'),
    );

    for (final app in popularApps) {
      expect(app.name, isNotEmpty, reason: app.id);
      expect(app.domains, isNotEmpty, reason: app.id);
      expect(File(app.iconAsset).existsSync(), isTrue, reason: app.iconAsset);
      for (final domain in app.domains) {
        expect(
          _domainPattern.hasMatch(domain),
          isTrue,
          reason: '${app.id}: $domain',
        );
      }
      for (final address in app.addresses) {
        final parts = address.split('/');
        expect(parts.length, 2, reason: address);
        final ip = InternetAddress.tryParse(parts.first);
        expect(ip, isNotNull, reason: address);
        final maxBits = ip!.type == InternetAddressType.IPv4 ? 32 : 128;
        expect(int.parse(parts.last), inInclusiveRange(1, maxBits));
      }
    }
  });

  test('selected popular apps become address rules', () {
    expect(popularAppRules(const []), isEmpty);
    expect(popularAppRules(const ['unknown']), isEmpty);

    final telegram = popularAppRules(const ['telegram', 'unknown']);
    expect(telegram, contains('domain:t.me'));
    expect(telegram, contains('geoip:91.108.4.0/22'));
    expect(telegram, contains('geoip:2001:b28:f23c::/47'));

    final everything = popularAppRules(popularApps.map((app) => app.id));
    for (final label in everything) {
      expect(SplitTunnelRule.parse(label), isNotNull, reason: label);
    }

    const config = SplitTunnelConfig(
      mode: SplitTunnelMode.onlySelected,
      rules: [
        SplitTunnelRule(type: SplitTunnelRuleType.domain, value: 'example.com'),
      ],
      apps: ['youtube'],
    );
    final payload =
        jsonDecode(config.rulesPayloadWith(popularAppRules(config.apps)))
            as List<dynamic>;
    expect(payload.first, 'domain:example.com');
    expect(payload, contains('domain:googlevideo.com'));
    expect(jsonDecode(config.rulesPayload), ['domain:example.com']);
  });

  testWidgets('popular apps show with their icons', (tester) async {
    final apps = [
      for (final app in popularApps)
        InstalledApp(
          name: app.name,
          packageName: app.id,
          iconSvg: File(app.iconAsset).readAsBytesSync(),
        ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [installedAppsProvider.overrideWith((ref) async => apps)],
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

    expect(find.text('Telegram'), findsOneWidget);
    expect(find.byType(SvgPicture), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
