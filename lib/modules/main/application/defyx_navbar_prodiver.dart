import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppScreen { home, speedTest, share }

final currentScreenProvider = StateProvider<AppScreen>((ref) => AppScreen.home);
