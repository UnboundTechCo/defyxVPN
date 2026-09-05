import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:defyx_vpn/firebase_options.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/shared/providers/language_provider.dart';
import 'package:defyx_vpn/shared/providers/haptics_provider.dart';
import 'package:defyx_vpn/shared/services/desktop_error_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';

const _lastAppVersionKey = 'last_app_version';

void main() async {
  runZonedGuarded(_runApp, (error, stack) {
    debugPrint('Uncaught zone error: $error');
    DesktopErrorLogger().logError('Zone', error, stack);
  });
}

Future<void> _runApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Silence Dart console logging in release builds.
  // Debug builds keep logs so developers can still trace issues.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  await dotenv.load();

  // Initialize language provider
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('Failed to load SharedPreferences: $e');
    await DesktopErrorLogger().logError('SharedPreferences.getInstance', e);
  }

  // On Windows/Linux, the native VPN engine cache can hold data from an older
  // app version that the current version can't parse. Clear it on upgrade so
  // stale cache never blocks startup (any cached offline flowline is refetched).
  if (prefs != null && (Platform.isWindows || Platform.isLinux)) {
    try {
      final currentVersion = (await PackageInfo.fromPlatform()).version;
      final lastVersion = prefs.getString(_lastAppVersionKey);
      if (lastVersion != null && lastVersion != currentVersion) {
        await VpnBridge().clearVpnCache();
      }
      await prefs.setString(_lastAppVersionKey, currentVersion);
    } catch (e) {
      debugPrint('Failed to run version-gated cache clear: $e');
      await DesktopErrorLogger().logError('VersionGatedCacheClear', e);
    }
  }

  // Note: VPN cache directory will be initialized after app starts
  // because native channel handler is not ready yet during main()
  // Initialize cache directory for VPN core
  try {
    final String vpnCacheDir = await VpnBridge().getSharedDirectory();
    await VpnBridge().setCacheDir(vpnCacheDir);
  } catch (e) {
    debugPrint('Failed to set cache directory: $e');
    await DesktopErrorLogger().logError('setCacheDir', e);
  }

  // Initialize Firebase only on supported platforms (not Windows)
  if (!Platform.isWindows && !Platform.isLinux) {
    await Firebase.initializeApp(
      name: "defyx-vpn",
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Firebase Crashlytics
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

    // Pass all uncaught Flutter errors to Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      // Also print to console in debug mode
      FlutterError.presentError(errorDetails);
    };

    // Pass all uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } else {
    // Crashlytics is unavailable on desktop; log to a local file instead.
    FlutterError.onError = (errorDetails) {
      DesktopErrorLogger().logError(
        'FlutterError',
        errorDetails.exception,
        errorDetails.stack,
      );
      FlutterError.presentError(errorDetails);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      DesktopErrorLogger().logError('PlatformDispatcher', error, stack);
      return true;
    };
  }

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

  prefs ??= await SharedPreferences.getInstance();
  final languageNotifier = LanguageNotifier(prefs);
  final hapticsNotifier = HapticsNotifier(prefs);

  // Run app in same zone as ensureInitialized
  runApp(
    ProviderScope(
      overrides: [
        languageProvider.overrideWith((ref) => languageNotifier),
        hapticsProvider.overrideWith((ref) => hapticsNotifier),
      ],
      child: const App(),
    ),
  );
}
