import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const String tunnelFlag = '--tun';
const String sessionFlag = '--session';

class TunnelSession {
  const TunnelSession({required this.port, required this.token});

  final int port;
  final String token;

  Map<String, dynamic> toJson() => {'port': port, 'token': token};

  static TunnelSession fromJson(Map<String, dynamic> json) =>
      TunnelSession(port: json['port'] as int, token: json['token'] as String);

  static String createToken() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }
}

class TunnelLink {
  TunnelLink(this._socket) {
    _subscription = utf8.decoder
        .bind(_socket)
        .transform(const LineSplitter())
        .listen(
          _onLine,
          onError: (_) => _closeMessages(),
          onDone: _closeMessages,
          cancelOnError: true,
        );
  }

  final Socket _socket;
  late final StreamSubscription<String> _subscription;
  final StreamController<Map<String, dynamic>> _messages =
      StreamController<Map<String, dynamic>>();

  Stream<Map<String, dynamic>> get messages => _messages.stream;

  void send(Map<String, dynamic> message) {
    try {
      _socket.write('${jsonEncode(message)}\n');
    } catch (_) {}
  }

  void _onLine(String line) {
    if (line.trim().isEmpty) return;
    try {
      final dynamic decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic> && !_messages.isClosed) {
        _messages.add(decoded);
      }
    } catch (_) {}
  }

  void _closeMessages() {
    if (!_messages.isClosed) _messages.close();
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    _closeMessages();
    _socket.destroy();
  }
}
