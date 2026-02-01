import 'dart:io';
import 'package:defyx_vpn/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  
  // Initialize Firebase only on supported platforms (not Windows)
  if (!Platform.isWindows && !Platform.isLinux) {
    await Firebase.initializeApp(
      name: "defyx-vpn",
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
  
  runApp(const ProviderScope(child: App()));
}
