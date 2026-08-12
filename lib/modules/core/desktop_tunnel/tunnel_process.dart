import 'dart:convert';
import 'dart:io';

import 'package:defyx_vpn/modules/core/desktop_tunnel/tunnel_link.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:flutter/services.dart';

class TunnelProcess {
  static bool matches(List<String> arguments) => arguments.contains(tunnelFlag);

  static Future<void> run(List<String> arguments) async {
    final String? sessionPath = _argumentValue(arguments, sessionFlag);
    if (sessionPath == null) exit(64);

    if (!await _acquireLock()) exit(65);

    final TunnelSession session;
    try {
      final String content = await File(sessionPath).readAsString();
      session = TunnelSession.fromJson(
        jsonDecode(content) as Map<String, dynamic>,
      );
    } catch (_) {
      exit(66);
    }

    final Socket socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        session.port,
        timeout: const Duration(seconds: 15),
      );
    } catch (_) {
      exit(67);
    }

    final VpnBridge bridge = VpnBridge();
    final TunnelLink link = TunnelLink(socket);
    link.send(<String, dynamic>{
      'type': 'hello',
      'token': session.token,
      'pid': pid,
    });

    _watchSignals(bridge);
    _forwardCoreLogs(link);

    await for (final Map<String, dynamic> message in link.messages) {
      if (message['type'] != 'command') continue;

      final dynamic id = message['id'];
      final dynamic name = message['name'];

      if (name == 'exit') {
        link.send(<String, dynamic>{'type': 'reply', 'id': id, 'ok': true});
        break;
      }

      bool ok = false;
      String? error;
      try {
        switch (name) {
          case 'start':
            ok = await bridge.startTunnel();
            if (!ok) error = 'the core refused to start the tunnel';
            break;
          case 'stop':
            await bridge.stopTunnel();
            ok = true;
            break;
          default:
            error = 'unknown command "$name"';
        }
      } catch (failure) {
        error = '$failure';
      }

      link.send(<String, dynamic>{
        'type': 'reply',
        'id': id,
        'ok': ok,
        if (error != null) 'error': error,
      });
    }

    await _stopAndExit(bridge, link);
  }

  static void _forwardCoreLogs(TunnelLink link) {
    try {
      const EventChannel channel = EventChannel('com.defyx.progress_events');
      channel.receiveBroadcastStream().listen((dynamic event) {
        link.send(<String, dynamic>{
          'type': 'event',
          'name': 'log',
          'message': '$event',
        });
      }, onError: (_) {});
    } catch (_) {}
  }

  static void _watchSignals(VpnBridge bridge) {
    final List<ProcessSignal> signals = Platform.isWindows
        ? <ProcessSignal>[ProcessSignal.sigint]
        : <ProcessSignal>[ProcessSignal.sigint, ProcessSignal.sigterm];

    for (final ProcessSignal signal in signals) {
      try {
        signal.watch().listen((_) async {
          try {
            await bridge.stopTunnel();
          } catch (_) {}
          exit(0);
        });
      } catch (_) {}
    }
  }

  static RandomAccessFile? _lockHandle;

  static Future<bool> _acquireLock() async {
    for (final String path in _lockCandidates()) {
      final RandomAccessFile handle;
      try {
        handle = await File(path).open(mode: FileMode.write);
      } catch (_) {
        continue;
      }
      try {
        await handle.lock(FileLock.exclusive);
        _lockHandle = handle;
        return true;
      } catch (_) {
        await handle.close();
        return false;
      }
    }
    return true;
  }

  static List<String> _lockCandidates() {
    final String separator = Platform.pathSeparator;
    if (Platform.isWindows) {
      return <String>['${Directory.systemTemp.path}${separator}defyx-tunnel.lock'];
    }
    return <String>[
      '/run/defyx-tunnel.lock',
      '/var/lock/defyx-tunnel.lock',
      '${Directory.systemTemp.path}${separator}defyx-tunnel.lock',
    ];
  }

  static Future<void> _stopAndExit(VpnBridge bridge, TunnelLink link) async {
    try {
      await bridge.stopTunnel();
    } catch (_) {}
    await link.dispose();
    exit(0);
  }

  static String? _argumentValue(List<String> arguments, String flag) {
    final int index = arguments.indexOf(flag);
    if (index >= 0 && index + 1 < arguments.length) return arguments[index + 1];
    for (final String argument in arguments) {
      if (argument.startsWith('$flag=')) {
        return argument.substring(flag.length + 1);
      }
    }
    return null;
  }
}
