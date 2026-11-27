import 'dart:convert';

import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_interface.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:defyx_vpn/shared/providers/flow_line_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Map<String, dynamic> _method(
  String label, [
  Map<String, dynamic> extra = const {},
]) => {'label': label, 'core': 'xray', 'enabled': true, 'steps': [], ...extra};

final _builtIn = _method('Built-in');
final _premium = _method('Gold DE', {'kind': 'premium', 'isPremium': true});
final _market = _method('Market NL', {'kind': 'market', 'isMarket': true});

const _vpnChannel = MethodChannel('com.defyx.vpn');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('withoutAccountMethods', () {
    test('keeps only built-in methods', () {
      final methods = [
        _builtIn,
        _method('Tagged built-in', {'kind': 'builtin'}),
        _premium,
        _market,
        _method('Invite reward', {'kind': 'invite_bounce'}),
        _method('Old premium', {'isPremium': true}),
        _method('Old market', {'isMarket': true}),
      ];

      final labels = [
        for (final method in withoutAccountMethods(methods)) method['label'],
      ];

      expect(labels, ['Built-in', 'Tagged built-in']);
    });
  });

  group('signing out', () {
    late _FakeSecureStorage storage;
    late ProviderContainer container;
    String cachedFlowLine = '';

    List<String> savedLabels() => [
      for (final method in jsonDecode(storage.values[flowLineKey]!) as List)
        (method as Map)['label'] as String,
    ];

    Future<void> setUp({
      bool signedIn = false,
      String mode = '',
      List<Map<String, dynamic>>? saved,
    }) async {
      SharedPreferences.setMockInitialValues({FlowLineNotifier.modeKey: mode});
      dotenv.loadFromString(envString: 'UPDATE_FLOWLINE_PERIOD=60');
      storage = _FakeSecureStorage();
      if (signedIn) storage.values[premiumTokenKey] = 'token';
      storage.values[flowLineKey] = jsonEncode(
        saved ?? [_premium, _market, _builtIn],
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_vpnChannel, (call) async {
            switch (call.method) {
              case 'getCachedFlowLine':
                return cachedFlowLine;
              case 'decodeAndVerifyFlowline':
                return call.arguments['flowLine'];
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_vpnChannel, null),
      );

      container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);
    }

    test('drops the account methods right away, offline too', () async {
      await setUp(signedIn: true);

      await container.read(authProvider.notifier).logout();

      expect(savedLabels(), ['Built-in']);
    });

    test('keeps the methods of an imported file', () async {
      await setUp(mode: FlowLineNotifier.importedMode);

      await container.read(flowlineServiceProvider).dropAccountMethods();

      expect(savedLabels(), ['Gold DE', 'Market NL', 'Built-in']);
    });

    test('keeps the methods while signed in', () async {
      await setUp(signedIn: true);

      await container.read(flowlineServiceProvider).dropAccountMethods();

      expect(savedLabels(), ['Gold DE', 'Market NL', 'Built-in']);
    });

    test('the cached flowline loaded at startup brings none back', () async {
      await setUp(saved: [_builtIn]);
      cachedFlowLine = jsonEncode({
        'flowLine': [_premium, _builtIn],
      });

      await container
          .read(flowlineServiceProvider)
          .saveFlowline(offlineMode: true);

      expect(savedLabels(), ['Built-in']);
    });

    test('an imported file keeps its premium methods signed out', () async {
      await setUp(saved: [_builtIn]);

      await container
          .read(flowlineServiceProvider)
          .saveFlowline(
            offlineMode: true,
            flowLine: jsonEncode({
              'flowLine': [_premium, _builtIn],
            }),
          );

      expect(savedLabels(), ['Gold DE', 'Built-in']);
    });
  });
}
