import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppScreen { home, speedTest, share, settings }

class AppScreenNotifier extends Notifier<AppScreen> {
  @override
  AppScreen build() => AppScreen.home;

  void setScreen(AppScreen screen) => state = screen;
}

final currentScreenProvider = NotifierProvider<AppScreenNotifier, AppScreen>(
  AppScreenNotifier.new,
);
