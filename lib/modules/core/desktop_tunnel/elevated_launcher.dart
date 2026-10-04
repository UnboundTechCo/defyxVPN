import 'dart:io';

class ElevationResult {
  const ElevationResult({required this.launched, this.process, this.error});

  final bool launched;
  final Process? process;
  final String? error;
}

class ElevatedLauncher {
  static const List<String> _passthroughVariables = <String>[
    'DISPLAY',
    'XAUTHORITY',
    'WAYLAND_DISPLAY',
    'XDG_RUNTIME_DIR',
    'XDG_SESSION_TYPE',
    'DBUS_SESSION_BUS_ADDRESS',
    'GDK_BACKEND',
  ];

  static Future<ElevationResult> launch(List<String> arguments) {
    final String executable = Platform.resolvedExecutable;
    if (Platform.isLinux) return _launchLinux(executable, arguments);
    if (Platform.isWindows) return _launchWindows(executable, arguments);
    return Future.value(
      const ElevationResult(
        launched: false,
        error: 'elevation is not available on this platform',
      ),
    );
  }

  static Future<ElevationResult> _launchLinux(
    String executable,
    List<String> arguments,
  ) async {
    final List<String> environment = <String>[
      for (final String name in _passthroughVariables)
        if ((Platform.environment[name] ?? '').isNotEmpty)
          '$name=${Platform.environment[name]}',
    ];

    try {
      final Process process = await Process.start('pkexec', <String>[
        'env',
        ...environment,
        executable,
        ...arguments,
      ]);
      return ElevationResult(launched: true, process: process);
    } catch (error) {
      return ElevationResult(launched: false, error: '$error');
    }
  }

  static Future<ElevationResult> _launchWindows(
    String executable,
    List<String> arguments,
  ) async {
    final String argumentList = arguments.map(_quote).join(',');
    final String command =
        'Start-Process -FilePath ${_quote(executable)} '
        '-ArgumentList $argumentList -Verb RunAs -WindowStyle Hidden';

    try {
      final ProcessResult result = await Process.run('powershell', <String>[
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        command,
      ]);
      if (result.exitCode != 0) {
        final String message = '${result.stderr}'.trim();
        return ElevationResult(
          launched: false,
          error: message.isEmpty ? 'elevation was declined' : message,
        );
      }
      return const ElevationResult(launched: true);
    } catch (error) {
      return ElevationResult(launched: false, error: '$error');
    }
  }

  static String _quote(String value) => "'${value.replaceAll("'", "''")}'";
}
