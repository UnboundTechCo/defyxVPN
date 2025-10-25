import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppScreen { home, speedTest, share, settings }

final currentScreenProvider = StateProvider<AppScreen>((ref) => AppScreen.home);
