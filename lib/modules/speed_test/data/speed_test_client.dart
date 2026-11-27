import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import '../application/services/speed_measurement_config.dart';

/// One completed download or upload.
class TransferSample {
  final int bytes;

  /// Time the transfer took, as Cloudflare's engine counts it: for downloads
  /// the whole request minus the server's own processing time, for uploads
  /// the time until the response headers arrive.
  final Duration duration;

  const TransferSample({required this.bytes, required this.duration});

  double get mbps {
    final micros = duration.inMicroseconds;
    if (micros <= 0) return 0;
    // bits per microsecond == megabits per second
    return bytes * SpeedMeasurementConfig.transferOverhead * 8 / micros;
  }
}

/// HTTP client for one speed test run against speed.cloudflare.com.
///
/// Each run gets its own client so the test never changes the app-wide one,
/// and so cancelling the run aborts its in-flight requests.
class SpeedTestClient {
  SpeedTestClient._(this._dio, this.cancelToken, this.viaVpnProxy) {
    // Closing the client also kills a response body that is still streaming.
    cancelToken.whenCancel.then((_) => close());
  }

  final Dio _dio;
  final CancelToken cancelToken;

  /// Whether requests go through the VPN core's local proxy.
  final bool viaVpnProxy;

  bool _closed = false;

  /// Creates a client. With [routeThroughVpnProxy] the requests go through
  /// the VPN core's local proxy, if it accepts connections; otherwise they
  /// go out directly.
  static Future<SpeedTestClient> create({
    required CancelToken cancelToken,
    required bool routeThroughVpnProxy,
    String baseUrl = SpeedMeasurementConfig.baseUrl,
    String proxyHost = SpeedMeasurementConfig.vpnProxyHost,
    int proxyPort = SpeedMeasurementConfig.vpnProxyPort,
  }) async {
    final useProxy =
        routeThroughVpnProxy && await _isReachable(proxyHost, proxyPort);
    if (routeThroughVpnProxy && !useProxy) {
      debugPrint(
        'Speed test: VPN proxy $proxyHost:$proxyPort is not reachable, '
        'measuring the direct connection instead',
      );
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: SpeedMeasurementConfig.connectTimeout,
        receiveTimeout: SpeedMeasurementConfig.receiveTimeout,
        sendTimeout: SpeedMeasurementConfig.sendTimeout,
        headers: {'User-Agent': SpeedMeasurementConfig.userAgent},
        // Error responses (e.g. 429 rate limiting) must never count as data.
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient()
          ..idleTimeout = const Duration(seconds: 15);
        // Explicit both ways: the app-wide AppTraffic proxy must not
        // decide which connection the test measures.
        client.findProxy = useProxy
            ? (_) => 'PROXY $proxyHost:$proxyPort'
            : (_) => 'DIRECT';
        return client;
      },
    );

    debugPrint(
      'Speed test: ${useProxy ? 'through the VPN proxy' : 'direct connection'}',
    );
    return SpeedTestClient._(dio, cancelToken, useProxy);
  }

  static Future<bool> _isReachable(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: SpeedMeasurementConfig.vpnProxyProbeTimeout,
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Round-trip time of an empty download, minus the server's processing time.
  Future<Duration> measureLatency(String measurementId) {
    return _retryIfRateLimited(() async {
      final stopwatch = Stopwatch()..start();
      final response = await _dio.get<ResponseBody>(
        '/__down',
        queryParameters: {'bytes': 0, 'measId': measurementId},
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancelToken,
      );
      final ttfb = stopwatch.elapsed;
      await response.data!.stream.drain<void>();
      _throwIfCancelled();

      final ping = ttfb - _serverTime(response.headers);
      return ping > const Duration(milliseconds: 1) ? ping : ttfb;
    });
  }

  /// Downloads [bytes] bytes. [onChunk] gets the size of every chunk as it
  /// arrives.
  Future<TransferSample> download(
    int bytes,
    String measurementId, {
    void Function(int chunkBytes)? onChunk,
  }) {
    return _retryIfRateLimited(() async {
      final stopwatch = Stopwatch()..start();
      final response = await _dio.get<ResponseBody>(
        '/__down',
        queryParameters: {'bytes': bytes, 'measId': measurementId},
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancelToken,
      );

      var received = 0;
      await for (final chunk in response.data!.stream) {
        if (cancelToken.isCancelled) break;
        received += chunk.length;
        onChunk?.call(chunk.length);
      }
      final elapsed = stopwatch.elapsed;
      _throwIfCancelled();

      if (received < bytes) {
        throw SpeedTestException('Incomplete download: $received of $bytes bytes');
      }
      return TransferSample(
        bytes: received,
        duration: elapsed - _serverTime(response.headers),
      );
    });
  }

  /// Uploads [payload]. [onSent] gets the number of bytes handed to the
  /// socket since the previous call, and the time since the request started.
  Future<TransferSample> upload(
    Uint8List payload,
    String measurementId, {
    void Function(int sentBytes, Duration sinceStart)? onSent,
  }) {
    return _retryIfRateLimited(() async {
      var reported = 0;
      final stopwatch = Stopwatch()..start();
      final response = await _dio.post<ResponseBody>(
        '/__up',
        queryParameters: {'measId': measurementId},
        data: _chunked(payload),
        options: Options(
          responseType: ResponseType.stream,
          contentType: 'application/octet-stream',
          headers: {Headers.contentLengthHeader: payload.length},
        ),
        cancelToken: cancelToken,
        onSendProgress: (sent, _) {
          if (sent <= reported) return;
          onSent?.call(sent - reported, stopwatch.elapsed);
          reported = sent;
        },
      );
      // The server answers once it has the whole body.
      final elapsed = stopwatch.elapsed;
      await response.data!.stream.drain<void>();
      _throwIfCancelled();

      return TransferSample(bytes: payload.length, duration: elapsed);
    });
  }

  /// Sends the results to Cloudflare's log endpoint, like their web client.
  Future<void> logResults(Map<String, dynamic> data) async {
    try {
      await _dio.post<void>(
        '/__log',
        data: data,
        options: Options(contentType: Headers.jsonContentType),
        cancelToken: cancelToken,
      );
    } catch (e) {
      debugPrint('Speed test: failed to log results: $e');
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _dio.close(force: true);
  }

  /// Upload body of [bytes] bytes: one random chunk repeated, which is cheap
  /// to build even for large sizes.
  static Uint8List createPayload(int bytes) {
    if (bytes <= 0) return Uint8List(0);
    final random = Random();
    final block = Uint8List(min(bytes, SpeedMeasurementConfig.uploadChunkSize));
    for (var i = 0; i < block.length; i++) {
      block[i] = random.nextInt(256);
    }
    final payload = Uint8List(bytes);
    for (var offset = 0; offset < bytes; offset += block.length) {
      payload.setRange(offset, min(offset + block.length, bytes), block);
    }
    return payload;
  }

  static Stream<List<int>> _chunked(Uint8List payload) async* {
    const chunkSize = SpeedMeasurementConfig.uploadChunkSize;
    for (var offset = 0; offset < payload.length; offset += chunkSize) {
      yield Uint8List.sublistView(
        payload,
        offset,
        min(offset + chunkSize, payload.length),
      );
    }
  }

  /// Retries a request once if Cloudflare answers with 429 Too Many Requests.
  Future<T> _retryIfRateLimited<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      final response = e.response;
      if (response?.statusCode != 429 || cancelToken.isCancelled) rethrow;
      await Future<void>.delayed(_retryDelay(response!));
      _throwIfCancelled();
      return request();
    }
  }

  static Duration _retryDelay(Response<dynamic> response) {
    final seconds = int.tryParse(
      response.headers.value(HttpHeaders.retryAfterHeader) ?? '',
    );
    if (seconds == null) return SpeedMeasurementConfig.rateLimitRetryDelay;
    final delay = Duration(seconds: seconds);
    return delay > SpeedMeasurementConfig.maxRateLimitRetryDelay
        ? SpeedMeasurementConfig.maxRateLimitRetryDelay
        : delay;
  }

  void _throwIfCancelled() {
    if (cancelToken.isCancelled) throw const SpeedTestCancelled();
  }

  static Duration _serverTime(Headers headers) =>
      parseServerTime(headers['server-timing']?.join(', '));

  static final _requestDuration = RegExp(
    r'(?:^|,\s*)cfReq(?:uest)?Dur(?:ation)?;\s*dur=([0-9.]+)',
    caseSensitive: false,
  );
  static final _speedDuration = RegExp(
    r'cfSpeed[a-zA-Z]*;\s*dur=([0-9.]+)',
    caseSensitive: false,
  );

  /// Server processing time from Cloudflare's `server-timing` header.
  @visibleForTesting
  static Duration parseServerTime(String? header) {
    if (header == null || header.isEmpty) return Duration.zero;
    const minMs = 0.01;

    var ms = double.tryParse(
          _requestDuration.firstMatch(header)?.group(1) ?? '',
        ) ??
        0;
    if (ms <= minMs) {
      ms = _speedDuration
          .allMatches(header)
          .map((m) => double.tryParse(m.group(1)!) ?? 0)
          .fold(0.0, (sum, value) => sum + value);
    }
    if (ms <= minMs) return Duration.zero;
    return Duration(microseconds: (ms * 1000).round());
  }
}

class SpeedTestException implements Exception {
  final String message;
  const SpeedTestException(this.message);

  @override
  String toString() => message;
}

/// Thrown when the run was cancelled while a request was in flight.
class SpeedTestCancelled implements Exception {
  const SpeedTestCancelled();

  @override
  String toString() => 'Speed test cancelled';
}
