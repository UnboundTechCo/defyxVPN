import 'dart:io';
import 'dart:typed_data';

import 'package:defyx_vpn/modules/speed_test/data/speed_test_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal stand-in for speed.cloudflare.com.
class _FakeSpeedServer {
  late final HttpServer _server;
  final List<String> requests = [];

  /// Status codes to answer with before serving normally.
  final List<int> failNext = [];

  /// When set, downloads send only this share of the requested bytes.
  double bodyShare = 1;

  /// When set, downloads trickle out slowly (for cancellation tests).
  bool slow = false;

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    requests.add('${request.method} ${request.uri.path}');
    final response = request.response;

    if (failNext.isNotEmpty) {
      await request.drain<void>();
      response.statusCode = failNext.removeAt(0);
      response.headers.set(HttpHeaders.retryAfterHeader, '0');
      response.write('error');
      await response.close();
      return;
    }

    response.headers.set('server-timing', 'cfRequestDuration;dur=2');
    if (request.uri.path == '/__down') {
      final requested = int.parse(request.uri.queryParameters['bytes']!);
      final bytes = (requested * bodyShare).round();
      response.contentLength = bytes;
      if (slow) {
        for (var sent = 0; sent < bytes; sent += 1000) {
          response.add(Uint8List(1000));
          await response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      } else {
        response.add(Uint8List(bytes));
      }
      await response.close();
    } else if (request.uri.path == '/__up') {
      final received = await request.fold<int>(0, (n, c) => n + c.length);
      response.write('$received');
      await response.close();
    } else {
      response.statusCode = 404;
      await response.close();
    }
  }
}

/// Forward HTTP proxy that counts what goes through it, like the VPN core's
/// local inbound.
class _CountingProxy {
  late final HttpServer _server;
  final HttpClient _upstream = HttpClient();
  int forwarded = 0;

  int get port => _server.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      forwarded++;
      final upstream = await _upstream.openUrl(request.method, request.uri);
      await upstream.addStream(request);
      final reply = await upstream.close();
      request.response.statusCode = reply.statusCode;
      reply.headers.forEach((name, values) {
        if (name != HttpHeaders.transferEncodingHeader) {
          request.response.headers.set(name, values);
        }
      });
      await request.response.addStream(reply);
      await request.response.close();
    });
  }

  Future<void> close() async {
    _upstream.close(force: true);
    await _server.close(force: true);
  }
}

Future<int> _closedPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

void main() {
  late _FakeSpeedServer server;
  final clients = <SpeedTestClient>[];

  Future<SpeedTestClient> client({
    CancelToken? cancelToken,
    bool viaProxy = false,
    int? proxyPort,
  }) async {
    final c = await SpeedTestClient.create(
      cancelToken: cancelToken ?? CancelToken(),
      routeThroughVpnProxy: viaProxy,
      baseUrl: server.baseUrl,
      proxyHost: '127.0.0.1',
      proxyPort: proxyPort ?? await _closedPort(),
    );
    clients.add(c);
    return c;
  }

  setUpAll(() => HttpOverrides.global = null);

  setUp(() async {
    server = _FakeSpeedServer();
    await server.start();
  });

  tearDown(() async {
    for (final c in clients) {
      c.close();
    }
    clients.clear();
    await server.close();
  });

  test('downloads, uploads and pings against the server', () async {
    final c = await client();
    final chunks = <int>[];

    final download = await c.download(200000, 'm1', onChunk: chunks.add);
    expect(download.bytes, 200000);
    expect(chunks.fold<int>(0, (a, b) => a + b), 200000);
    expect(download.mbps, greaterThan(0));

    var sent = 0;
    final payload = SpeedTestClient.createPayload(300000);
    final upload = await c.upload(
      payload,
      'm1',
      onSent: (bytes, _) => sent += bytes,
    );
    expect(upload.bytes, 300000);
    expect(sent, 300000);

    final ping = await c.measureLatency('m1');
    expect(ping, greaterThan(Duration.zero));
    expect(c.viaVpnProxy, isFalse);
  });

  test('goes through the VPN proxy when asked and it is reachable', () async {
    final proxy = _CountingProxy();
    await proxy.start();
    addTearDown(proxy.close);

    final c = await client(viaProxy: true, proxyPort: proxy.port);
    expect(c.viaVpnProxy, isTrue);

    await c.measureLatency('m2');
    final sample = await c.download(50000, 'm2');
    expect(sample.bytes, 50000);
    expect(proxy.forwarded, 2);
  });

  test('falls back to a direct connection when the proxy is down', () async {
    final c = await client(viaProxy: true);
    expect(c.viaVpnProxy, isFalse);
    expect((await c.download(1000, 'm3')).bytes, 1000);
  });

  test('retries once when rate limited (429)', () async {
    server.failNext.add(429);
    final c = await client();
    final sample = await c.download(1000, 'm4');
    expect(sample.bytes, 1000);
    expect(server.requests.length, 2);
  });

  test('error responses are never counted as data', () async {
    server.failNext.addAll([429, 429]);
    final c = await client();
    await expectLater(c.download(1000, 'm5'), throwsA(isA<DioException>()));

    server.failNext.add(403);
    await expectLater(c.download(1000, 'm5'), throwsA(isA<DioException>()));
  });

  test('a short body is rejected', () async {
    server.bodyShare = 0.5;
    final c = await client();
    await expectLater(
      c.download(10000, 'm6'),
      throwsA(isA<SpeedTestException>()),
    );
  });

  test('cancelling stops a download that is streaming', () async {
    server.slow = true;
    final token = CancelToken();
    final c = await client(cancelToken: token);

    var received = 0;
    final download = c.download(
      1000000,
      'm7',
      onChunk: (bytes) {
        received += bytes;
        if (!token.isCancelled) token.cancel();
      },
    );

    final stopwatch = Stopwatch()..start();
    await expectLater(download, throwsA(anything));
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    expect(received, lessThan(1000000));
  });

  test('createPayload builds bodies of the exact size', () {
    expect(SpeedTestClient.createPayload(0), isEmpty);
    expect(SpeedTestClient.createPayload(10), hasLength(10));
    expect(SpeedTestClient.createPayload(100001), hasLength(100001));
  });
}
