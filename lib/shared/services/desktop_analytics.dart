import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Analytics for Windows and Linux, which have no Firebase Analytics or
/// Crashlytics SDK.
///
/// Events go over HTTPS to the Firebase project's Desktop web app's data
/// stream with the GA4 Measurement Protocol. Windows and Linux share it;
/// reports tell them apart by operating system. Errors are sent as `exception`
/// events. macOS has the Firebase SDKs and doesn't use this.
///
/// This class doesn't check consent: FirebaseAnalyticsService and
/// CrashReportingService only call it once the user has agreed, see
/// TelemetryConsent.
class DesktopAnalytics {
  DesktopAnalytics._();
  static final instance = DesktopAnalytics._();

  static const _clientIdKey = 'desktop_analytics_client_id';
  static const _sessionTimeout = Duration(minutes: 30);
  static const _requestTimeout = Duration(seconds: 15);

  /// Stops an error loop from sending thousands of events.
  static const _maxExceptionsPerRun = 25;

  // Measurement Protocol limits.
  static const _maxParams = 25;
  static const _maxNameLength = 40;
  static const _maxParamValueLength = 100;
  static const _maxUserPropertyLength = 36;

  static final _endpoint = Uri.https('www.google-analytics.com', '/mp/collect');

  static String _env(String key) =>
      dotenv.isInitialized ? (dotenv.env[key] ?? '').trim() : '';

  static String get _measurementId => _env('FIREBASE_DESKTOP_MEASUREMENT_ID');
  static String get _apiSecret => _env('FIREBASE_DESKTOP_MP_API_SECRET');

  /// Whether this platform reports through here and the build has the
  /// stream's measurement ID and API secret.
  static bool get isSupported =>
      (Platform.isWindows || Platform.isLinux) &&
      _measurementId.isNotEmpty &&
      _apiSecret.isNotEmpty;

  Future<void>? _ready;
  String? _clientId;
  String? _userId;
  final Map<String, String> _userProperties = {};
  int? _sessionId;
  DateTime? _lastEventAt;
  int _exceptionsSent = 0;

  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    if (!isSupported) return;
    try {
      try {
        await (_ready ??= _init());
      } catch (_) {
        _ready = null; // Try again with the next event.
        rethrow;
      }
      final clientId = _clientId;
      if (clientId == null) return;
      final body = payload(
        clientId: clientId,
        sessionId: _currentSessionId(),
        name: name,
        parameters: parameters,
        userId: _userId,
        userProperties: _userProperties,
        device: _device,
      );
      await _send(body);
    } catch (e) {
      debugPrint('Desktop analytics error: $e');
    }
  }

  /// Sends an error as an `exception` event. Only the error's type and a
  /// shortened message go out, with IP addresses and the home folder removed.
  Future<void> logException(
    Object error, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!isSupported || _exceptionsSent >= _maxExceptionsPerRun) return;
    _exceptionsSent++;
    await logEvent('exception', {
      'description': describeError(error, home: _homeDirectory),
      'error_type': error.runtimeType.toString(),
      if (reason != null) 'reason': reason,
      'fatal': fatal ? 1 : 0,
    });
  }

  void setUserId(String? userId) => _userId = userId;

  void setUserProperty(String name, String? value) {
    if (value == null) {
      _userProperties.remove(name);
    } else {
      _userProperties[name] = value;
    }
  }

  /// Forgets this install's analytics ID, so a later opt-in starts as a new
  /// user.
  Future<void> reset() async {
    _ready = null;
    _clientId = null;
    _userId = null;
    _sessionId = null;
    _lastEventAt = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clientIdKey);
    } catch (e) {
      debugPrint('Failed to reset desktop analytics: $e');
    }
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    var clientId = prefs.getString(_clientIdKey);
    if (clientId == null) {
      // Same shape as the IDs gtag.js makes: random number, then first-seen
      // time in seconds.
      final random = Random.secure().nextInt(0x7fffffff);
      final seconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      clientId = '$random.$seconds';
      await prefs.setString(_clientIdKey, clientId);
    }
    _clientId = clientId;
    try {
      final info = await PackageInfo.fromPlatform();
      _userProperties.putIfAbsent('app_version', () => info.version);
    } catch (e) {
      debugPrint('Desktop analytics: no app version: $e');
    }
  }

  /// A new session starts after 30 minutes without events, as on the web.
  int _currentSessionId() {
    final now = DateTime.now();
    final last = _lastEventAt;
    if (_sessionId == null ||
        last == null ||
        now.difference(last) > _sessionTimeout) {
      _sessionId = now.millisecondsSinceEpoch ~/ 1000;
    }
    _lastEventAt = now;
    return _sessionId!;
  }

  Map<String, String> get _device => {
        'category': 'desktop',
        'operating_system': Platform.isWindows ? 'Windows' : 'Linux',
        'operating_system_version': osVersion(Platform.operatingSystemVersion),
        'language': Platform.localeName.split('.').first.replaceAll('_', '-'),
      };

  static String? get _homeDirectory => Platform.isWindows
      ? Platform.environment['USERPROFILE']
      : Platform.environment['HOME'];

  // Goes through AppTraffic, so while the VPN is up this leaves through it.
  Future<void> _send(Map<String, Object?> body) async {
    final client = HttpClient()..connectionTimeout = _requestTimeout;
    try {
      final uri = _endpoint.replace(queryParameters: {
        'measurement_id': _measurementId,
        'api_secret': _apiSecret,
      });
      final request = await client.postUrl(uri).timeout(_requestTimeout);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close().timeout(_requestTimeout);
      await response.drain<void>();
    } finally {
      client.close(force: true);
    }
  }

  /// The request body for one event.
  @visibleForTesting
  static Map<String, Object?> payload({
    required String clientId,
    required int sessionId,
    required String name,
    Map<String, Object>? parameters,
    String? userId,
    Map<String, String> userProperties = const {},
    Map<String, String> device = const {},
  }) {
    final params = <String, Object>{};
    for (final entry in (parameters ?? const <String, Object>{}).entries) {
      // Leave room for the two session fields below.
      if (params.length >= _maxParams - 2) break;
      params[_truncate(entry.key, _maxNameLength)] = _paramValue(entry.value);
    }
    // Without these GA4 leaves the event out of sessions and active users.
    params['session_id'] = sessionId;
    params['engagement_time_msec'] = 100;

    return {
      'client_id': clientId,
      if (userId != null) 'user_id': userId,
      if (userProperties.isNotEmpty)
        'user_properties': {
          for (final entry in userProperties.entries)
            _truncate(entry.key, _maxNameLength): {
              'value': _truncate(entry.value, _maxUserPropertyLength),
            },
        },
      if (device.isNotEmpty) 'device': device,
      'events': [
        {'name': _truncate(name, _maxNameLength), 'params': params},
      ],
    };
  }

  static Object _paramValue(Object value) =>
      value is num ? value : _truncate(value.toString(), _maxParamValueLength);

  static String _truncate(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);

  static final _ipv4 = RegExp(r'\b\d{1,3}(?:\.\d{1,3}){3}\b');
  static final _ipv6 = RegExp(r'(?:[0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}');

  /// The error's message, cut to fit one event field, with IP addresses (VPN
  /// servers among them) and the user's home folder taken out.
  @visibleForTesting
  static String describeError(Object error, {String? home}) {
    var text = error.toString();
    if (home != null && home.isNotEmpty) {
      text = text.replaceAll(home, '~');
    }
    text = text
        .replaceAll(_ipv4, '<ip>')
        .replaceAll(_ipv6, '<ip>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return _truncate(text, _maxParamValueLength);
  }

  /// A short version from [Platform.operatingSystemVersion]: Windows reports
  /// `"Windows 10 Pro" 10.0 (Build 19045)`, Linux the full kernel string.
  @visibleForTesting
  static String osVersion(String raw) {
    final windows = RegExp(r'(\d+\.\d+) \(Build (\d+)\)').firstMatch(raw);
    if (windows != null) return '${windows[1]}.${windows[2]}';
    return RegExp(r'\d+(?:\.\d+)+(?:-[\w.-]+)?').firstMatch(raw)?[0] ?? '';
  }
}
