import 'dart:convert';
import 'dart:io';

import 'package:defyx_vpn/common/dtos/subscription_usage_dto.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service_interface.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_settings.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_interface.dart';
import 'package:defyx_vpn/core/premium/api_premium.dart';
import 'package:defyx_vpn/modules/settings/providers/marketplace_info_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _label = 'Premium 1M DE';
const _link = 'https://panel.example.com:2096/sub/1c5e7a42';
const _jumpedLink = 'https://sub2.example.com:9449/tiger/1c5e7a42';
const _usageJson = {
  'used_volume_gb': 201,
  'remaining_volume_gb': 99,
  'total_volume_gb': 300,
  'remaining_days': 3,
  'total_days': 60,
  'expire_at': '2026-11-27T18:02:55.918Z',
};

String _flowLine(String link) => jsonEncode([
  {'label': 'WARP', 'enabled': true},
  {
    'label': 'Premium 1M SOS',
    'isPremium': true,
    'steps': [
      {'url': 'vless://id@host:1'},
    ],
  },
  {
    'label': _label,
    'isPremium': true,
    'steps': [
      {'url': 'base64://dmxlc3M6Ly8='},
      {'url': link},
    ],
  },
]);

class _FakePremiumServer {
  late final HttpServer _server;
  final List<String> requests = [];
  final List<String> usageLinks = [];
  final List<Object?> transferBodies = [];
  final List<String?> authorizations = [];
  int? failStatus;
  Object failBody = const {'message': 'Unauthorized', 'statusCode': 401};

  String get baseUrl => 'http://127.0.0.1:${_server.port}/';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final segments = request.uri.pathSegments;
    requests.add('${request.method} ${request.uri.path}');
    authorizations.add(request.headers.value(HttpHeaders.authorizationHeader));

    final response = request.response;
    response.headers.contentType = ContentType.json;

    if (failStatus != null) {
      response.statusCode = failStatus!;
      response.write(jsonEncode(failBody));
    } else if (request.method == 'GET' &&
        segments.length == 3 &&
        segments[1] == 'usage-link') {
      usageLinks.add(segments.last);
      response.write(jsonEncode(_usageJson));
    } else if (request.method == 'PATCH' &&
        request.uri.path == '/subscription/transfer-server') {
      transferBodies.add(jsonDecode(body));
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  }
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

class _FakeFlowlineService implements IFlowlineService {
  final _FakeSecureStorage storage;
  final List<({bool offlineMode, bool forceUpdate})> saves = [];

  _FakeFlowlineService(this.storage);

  @override
  Future<void> saveFlowline({
    required bool offlineMode,
    String? flowLine,
    bool forceUpdate = false,
  }) async {
    saves.add((offlineMode: offlineMode, forceUpdate: forceUpdate));
    storage.values[flowLineKey] = _flowLine(_jumpedLink);
  }

  @override
  Future<String> getFlowline() async => '';

  @override
  Future<String> getCachedFlowLine() async => '';

  @override
  Future<String> decodeAndVerifyFlowline(String flowLine) async => flowLine;

  @override
  Future<FlowlineSettings> getFlowlineSettings() async =>
      FlowlineSettings(disabledAdmob: [], baseUrls: []);

  @override
  Future<FlowlineSettings?> getSavedFlowlineSettings() async =>
      FlowlineSettings(disabledAdmob: [], baseUrls: []);

  @override
  Future<void> dropAccountMethods() async {}
}

class _FakePremiumApiNotifier extends PremiumApiServiceNotifier {
  final String baseUrl;

  _FakePremiumApiNotifier(this.baseUrl);

  @override
  Future<PremiumApiService> build() async =>
      PremiumApiService(baseUrl: baseUrl, token: 'test-token');
}

void main() {
  group('SubscriptionLinkResolver', () {
    test('returns the subscription link of the matching premium method', () {
      expect(
        SubscriptionLinkResolver.fromFlowLine(_flowLine(_link), _label),
        _link,
      );
    });

    test('returns null when the method has no subscription link', () {
      expect(
        SubscriptionLinkResolver.fromFlowLine(
          _flowLine(_link),
          'Premium 1M SOS',
        ),
        isNull,
      );
    });

    test('returns null for unknown labels and broken flowlines', () {
      expect(
        SubscriptionLinkResolver.fromFlowLine(_flowLine(_link), 'Unknown'),
        isNull,
      );
      expect(
        SubscriptionLinkResolver.fromFlowLine(_flowLine(_link), 'WARP'),
        isNull,
      );
      expect(SubscriptionLinkResolver.fromFlowLine(null, _label), isNull);
      expect(SubscriptionLinkResolver.fromFlowLine('', _label), isNull);
      expect(SubscriptionLinkResolver.fromFlowLine('{"a":1}', _label), isNull);
      expect(SubscriptionLinkResolver.fromFlowLine('not json', _label), isNull);
    });
  });

  group('SubscriptionUsageResponse', () {
    test('parses the response and computes the used fractions', () {
      final usage = SubscriptionUsageResponse.fromJson(_usageJson);

      expect(usage.remainingVolumeGb, 99);
      expect(usage.totalVolumeGb, 300);
      expect(usage.remainingDays, 3);
      expect(usage.totalDays, 60);
      expect(usage.expireAt, DateTime.utc(2026, 11, 27, 18, 2, 55, 918));
      expect(usage.usedVolumeFraction, closeTo(0.67, 0.001));
      expect(usage.usedDaysFraction, closeTo(0.95, 0.001));
    });

    test('keeps the fractions inside 0..1 for empty or overused plans', () {
      final empty = SubscriptionUsageResponse.fromJson({
        ..._usageJson,
        'total_volume_gb': 0,
        'total_days': 0,
      });
      final overused = SubscriptionUsageResponse.fromJson({
        ..._usageJson,
        'remaining_volume_gb': -5.5,
        'remaining_days': -2,
      });

      expect(empty.usedVolumeFraction, 0);
      expect(empty.usedDaysFraction, 0);
      expect(overused.usedVolumeFraction, 1);
      expect(overused.usedDaysFraction, 1);
    });
  });

  group('PremiumApiService', () {
    late _FakePremiumServer server;
    late PremiumApiService api;

    setUp(() async {
      server = _FakePremiumServer();
      await server.start();
      api = PremiumApiService(baseUrl: server.baseUrl, token: 'test-token');
    });

    tearDown(() => server.close());

    test('gets the usage with the encoded subscription link', () async {
      final usage = await api.getSubscriptionUsage(_link);

      expect(
        server.requests.single,
        startsWith('GET /subscription/usage-link/'),
      );
      expect(
        server.requests.single,
        contains('https%3A%2F%2Fpanel.example.com'),
      );
      expect(server.usageLinks.single, _link);
      expect(server.authorizations.single, 'Bearer test-token');
      expect(usage.remainingVolumeGb, 99);
      expect(usage.remainingDays, 3);
    });

    test('reports the server message when the usage is not found', () async {
      server.failStatus = 404;
      server.failBody = {
        'message': 'Subscription not found',
        'statusCode': 404,
      };

      await expectLater(
        api.getSubscriptionUsage(_link),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Subscription not found'),
          ),
        ),
      );
    });

    test('reports an expired token for the usage request', () async {
      server.failStatus = 401;

      await expectLater(
        api.getSubscriptionUsage(_link),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Token expired'),
          ),
        ),
      );
    });

    test('patches transfer-server with the subscription link', () async {
      await api.transferServer(_link);

      expect(server.requests.single, 'PATCH /subscription/transfer-server');
      expect(server.transferBodies.single, {'link': _link});
      expect(server.authorizations.single, 'Bearer test-token');
    });

    test('reports the server message when no other server exists', () async {
      server.failStatus = 404;
      server.failBody = {
        'message': 'No alternative config storage found for the same country',
        'statusCode': 404,
      };

      await expectLater(
        api.transferServer(_link),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('No alternative config storage found'),
          ),
        ),
      );
    });

    test('falls back to a generic message for non JSON errors', () async {
      server.failStatus = 404;
      server.failBody = 'gateway';

      await expectLater(
        api.transferServer(_link),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Resource not found'),
          ),
        ),
      );
    });

    test('reports a connection error when the server is unreachable', () async {
      await server.close();

      await expectLater(api.transferServer(_link), throwsException);
      await expectLater(api.getSubscriptionUsage(_link), throwsException);
    });
  });

  group('MarketplaceInfoService', () {
    late _FakePremiumServer server;
    late _FakeSecureStorage storage;
    late _FakeFlowlineService flowlineService;
    late ProviderContainer container;

    setUp(() async {
      server = _FakePremiumServer();
      await server.start();
      storage = _FakeSecureStorage()..values[flowLineKey] = _flowLine(_link);
      flowlineService = _FakeFlowlineService(storage);
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          flowlineServiceProvider.overrideWithValue(flowlineService),
          premiumApiServiceProvider.overrideWith(
            () => _FakePremiumApiNotifier(server.baseUrl),
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await server.close();
    });

    test('loads the usage with the link stored in the flowline', () async {
      final usage = await container.read(
        subscriptionUsageProvider(_label).future,
      );

      expect(server.usageLinks.single, _link);
      expect(usage.totalDays, 60);
    });

    test('fails without a request when the method has no link', () async {
      final service = container.read(marketplaceInfoServiceProvider);

      await expectLater(
        service.getUsage('Premium 1M SOS'),
        throwsA(isA<SubscriptionLinkNotFoundException>()),
      );
      await expectLater(
        service.jumpServer('Premium 1M SOS'),
        throwsA(isA<SubscriptionLinkNotFoundException>()),
      );
      expect(server.requests, isEmpty);
      expect(flowlineService.saves, isEmpty);
    });

    test(
      'jumps, updates the flowline and reloads usage with the new link',
      () async {
        final subscription = container.listen(
          subscriptionUsageProvider(_label),
          (_, _) {},
        );
        await container.read(subscriptionUsageProvider(_label).future);

        await container.read(marketplaceInfoServiceProvider).jumpServer(_label);
        container.invalidate(subscriptionUsageProvider(_label));
        await container.read(subscriptionUsageProvider(_label).future);
        subscription.close();

        expect(server.transferBodies.single, {'link': _link});
        expect(flowlineService.saves.single, (
          offlineMode: false,
          forceUpdate: true,
        ));
        expect(server.usageLinks, [_link, _jumpedLink]);
        expect(server.requests.map((request) => request.split(' ').first), [
          'GET',
          'PATCH',
          'GET',
        ]);
      },
    );

    test('does not update the flowline when the jump request fails', () async {
      server.failStatus = 404;
      server.failBody = {
        'message': 'No alternative config storage found for the same country',
      };

      await expectLater(
        container.read(marketplaceInfoServiceProvider).jumpServer(_label),
        throwsException,
      );
      expect(flowlineService.saves, isEmpty);
      expect(storage.values[flowLineKey], _flowLine(_link));
    });
  });
}
