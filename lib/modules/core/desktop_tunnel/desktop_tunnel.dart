import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:defyx_vpn/modules/core/desktop_tunnel/elevated_launcher.dart';
import 'package:defyx_vpn/modules/core/desktop_tunnel/tunnel_link.dart';
import 'package:path_provider/path_provider.dart';

class DesktopTunnel {
  DesktopTunnel._();

  static final DesktopTunnel instance = DesktopTunnel._();

  static const Duration _handshakeTimeout = Duration(seconds: 120);
  static const Duration _commandTimeout = Duration(seconds: 45);

  ServerSocket? _server;
  TunnelLink? _link;
  Process? _process;
  File? _sessionFile;
  String? _token;
  Completer<bool>? _handshake;
  Future<bool>? _preparing;
  final Map<int, Completer<Map<String, dynamic>>> _requests =
      <int, Completer<Map<String, dynamic>>>{};
  int _nextRequestId = 1;
  bool _tunnelUp = false;
  String? _lastError;

  void Function(String message)? onLog;

  bool get isSupported => Platform.isLinux || Platform.isWindows;

  bool get isConnected => _link != null;

  bool get isTunnelUp => _tunnelUp;

  String? get lastError => _lastError;

  Future<bool> prepare() {
    if (_link != null) return Future<bool>.value(true);
    return _preparing ??= _spawn().whenComplete(() => _preparing = null);
  }

  Future<bool> start() async {
    if (!await prepare()) return false;
    try {
      final Map<String, dynamic> reply = await _request('start');
      _tunnelUp = reply['ok'] == true;
      if (!_tunnelUp) {
        _lastError = reply['error'] as String? ?? 'the tunnel refused to start';
      }
      return _tunnelUp;
    } catch (error) {
      _lastError = '$error';
      _tunnelUp = false;
      return false;
    }
  }

  Future<void> stop() async {
    if (_link == null) {
      _tunnelUp = false;
      return;
    }
    try {
      await _request('stop');
    } catch (error) {
      _lastError = '$error';
    }
    _tunnelUp = false;
  }

  Future<void> dispose() async {
    if (_link != null) {
      try {
        await _request('exit').timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    await _teardown();
  }

  Future<bool> _spawn() async {
    if (!isSupported) {
      _lastError = 'elevation is not available on this platform';
      return false;
    }

    await _teardown();

    try {
      final ServerSocket server = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      _server = server;
      _token = TunnelSession.createToken();
      _sessionFile = await _writeSession(
        TunnelSession(port: server.port, token: _token!),
      );

      final Completer<bool> handshake = Completer<bool>();
      _handshake = handshake;
      server.listen(_onConnection, onError: (_) {});

      final ElevationResult result = await ElevatedLauncher.launch(<String>[
        tunnelFlag,
        sessionFlag,
        _sessionFile!.path,
      ]);
      if (!result.launched) {
        _lastError = result.error ?? 'elevation was declined';
        await _teardown();
        return false;
      }

      _process = result.process;
      final StringBuffer output = StringBuffer();
      void collect(String chunk) {
        output.write(chunk);
        final String text = chunk.trim();
        if (text.isNotEmpty) onLog?.call(text);
      }

      _process?.stdout.transform(utf8.decoder).listen(collect);
      _process?.stderr.transform(utf8.decoder).listen(collect);
      _process?.exitCode.then((int code) {
        if (!handshake.isCompleted) {
          final String details = output.toString().trim();
          _lastError = details.isEmpty
              ? 'the tunnel process exited with code $code'
              : 'the tunnel process exited with code $code: $details';
          handshake.complete(false);
        }
      });

      final bool connected = await handshake.future.timeout(
        _handshakeTimeout,
        onTimeout: () {
          _lastError = 'the tunnel process did not report back in time';
          return false;
        },
      );

      if (!connected) {
        await _teardown();
        return false;
      }

      await _deleteSessionFile();
      return true;
    } catch (error) {
      _lastError = '$error';
      await _teardown();
      return false;
    }
  }

  void _onConnection(Socket socket) {
    if (!socket.remoteAddress.isLoopback || _link != null) {
      socket.destroy();
      return;
    }

    final TunnelLink link = TunnelLink(socket);
    bool authenticated = false;

    link.messages.listen(
      (Map<String, dynamic> message) {
        if (!authenticated) {
          if (message['type'] == 'hello' && message['token'] == _token) {
            authenticated = true;
            _link = link;
            final Completer<bool>? handshake = _handshake;
            if (handshake != null && !handshake.isCompleted) {
              handshake.complete(true);
            }
          } else {
            link.dispose();
          }
          return;
        }
        _onMessage(message);
      },
      onDone: () => _onDisconnected(link),
      onError: (_) => _onDisconnected(link),
    );
  }

  void _onMessage(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'reply':
        final dynamic id = message['id'];
        final Completer<Map<String, dynamic>>? completer = _requests.remove(id);
        if (completer != null && !completer.isCompleted) {
          completer.complete(message);
        }
        break;
      case 'event':
        if (message['name'] == 'tunnelStopped') _tunnelUp = false;
        if (message['name'] == 'log') {
          final String text = '${message['message']}'.trim();
          if (text.isNotEmpty) onLog?.call(text);
        }
        break;
    }
  }

  void _onDisconnected(TunnelLink link) {
    if (_link != link) return;
    _link = null;
    _tunnelUp = false;
    for (final Completer<Map<String, dynamic>> completer in _requests.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('the tunnel process disconnected'),
        );
      }
    }
    _requests.clear();
  }

  Future<Map<String, dynamic>> _request(String name) {
    final TunnelLink? link = _link;
    if (link == null) {
      return Future<Map<String, dynamic>>.error(
        StateError('the tunnel process is not connected'),
      );
    }

    final int id = _nextRequestId++;
    final Completer<Map<String, dynamic>> completer =
        Completer<Map<String, dynamic>>();
    _requests[id] = completer;
    link.send(<String, dynamic>{'type': 'command', 'id': id, 'name': name});

    return completer.future.timeout(
      _commandTimeout,
      onTimeout: () {
        _requests.remove(id);
        throw TimeoutException('the tunnel did not answer "$name" in time');
      },
    );
  }

  Future<File> _writeSession(TunnelSession session) async {
    final Directory directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final File file = File(
      '${directory.path}${Platform.pathSeparator}tunnel-session.json',
    );
    await file.writeAsString(jsonEncode(session.toJson()), flush: true);
    if (!Platform.isWindows) {
      await Process.run('chmod', <String>['600', file.path]);
    }
    return file;
  }

  Future<void> _deleteSessionFile() async {
    try {
      await _sessionFile?.delete();
    } catch (_) {}
    _sessionFile = null;
  }

  Future<void> _teardown() async {
    final TunnelLink? link = _link;
    _link = null;
    _tunnelUp = false;
    _handshake = null;
    _token = null;
    _process = null;
    _requests.clear();
    await link?.dispose();
    await _server?.close();
    _server = null;
    await _deleteSessionFile();
  }
}
