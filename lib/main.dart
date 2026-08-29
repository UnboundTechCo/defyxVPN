import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/shared/providers/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared/services/telemetry_consent_service.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Silence Dart console logging in release builds.
  // Debug builds keep logs so developers can still trace issues.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  await dotenv.load();

  // Note: VPN cache directory will be initialized after app starts
  // because native channel handler is not ready yet during main()
  // Initialize cache directory for VPN core
  try {
    final String vpnCacheDir = await VpnBridge().getSharedDirectory();
    await VpnBridge().setCacheDir(vpnCacheDir);
  } catch (e) {
    debugPrint('Failed to set cache directory: $e');
  }

  // Firebase and Crashlytics stay uninitialized until telemetry is granted.
  await TelemetryConsentService().initialize();

  // Only lock orientation on mobile devices, not on Android TV
  if (Platform.isAndroid || Platform.isIOS) {
    // Check if running on Android TV by checking screen size will be done in app
    // For now, we'll set orientation based on platform detection
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e) {
      debugPrint('Could not set orientations: $e');
    }
  }

  // Initialize language provider
  final prefs = await SharedPreferences.getInstance();
  final languageNotifier = LanguageNotifier(prefs);

  // Run app in same zone as ensureInitialized
  runApp(
    ProviderScope(
      overrides: [languageProvider.overrideWith((ref) => languageNotifier)],
      child: const App(),
    ),
  );
}
