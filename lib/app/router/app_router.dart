import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../modules/main/presentation/screens/main_screen.dart';
import '../../modules/splash/presentation/splash_screen.dart';
import '../../modules/settings/presentation/screens/settings_screen.dart';
import '../../modules/speed_test/presentation/screens/speed_test_screen.dart';
import '../../shared/layout/navbar/defyx_navbar.dart';

enum SlideDirection { leftToRight, rightToLeft }

enum DefyxVPNRoutes {
  splash("/splash"),
  main("/main"),
  settings("/settings"),
  speedTest("/speedTest");

  final String route;
  const DefyxVPNRoutes(this.route);

  @override
  String toString() => name;
}

Widget _buildSlideTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
  SlideDirection direction,
) {
  const curve = Curves.fastOutSlowIn;

  final Offset beginOffset, endOffset;
  if (direction == SlideDirection.rightToLeft) {
    beginOffset = const Offset(1.0, 0.0);
    endOffset = const Offset(-1.0, 0.0);
  } else {
    beginOffset = const Offset(-1.0, 0.0);
    endOffset = const Offset(1.0, 0.0);
  }

  final slideAnimation = animation.drive(
    Tween(begin: beginOffset, end: Offset.zero).chain(
      CurveTween(curve: curve),
    ),
  );

  final slideOutAnimation = secondaryAnimation.drive(
    Tween(begin: Offset.zero, end: endOffset).chain(
      CurveTween(curve: curve),
    ),
  );

  final fadeAnimation = animation.drive(
    Tween(begin: 0.0, end: 1.0).chain(
      CurveTween(curve: curve),
    ),
  );

  final fadeOutAnimation = secondaryAnimation.drive(
    Tween(begin: 1.0, end: 0.0).chain(
      CurveTween(curve: curve),
    ),
  );

  return Stack(
    children: [
      Transform.translate(
        offset: slideOutAnimation.value,
        child: Opacity(
          opacity: fadeOutAnimation.value,
          child: const SizedBox.shrink(),
        ),
      ),
      Transform.translate(
        offset: slideAnimation.value,
        child: Opacity(
          opacity: fadeAnimation.value,
          child: child,
        ),
      ),
    ],
  );
}

CustomTransitionPage<void> _createPageAnimation(
  Widget child,
  LocalKey key,
  SlideDirection direction,
) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        _buildSlideTransition(
      context,
      animation,
      secondaryAnimation,
      child,
      direction,
    ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: DefyxVPNRoutes.splash.route,
    routes: [
      GoRoute(
        path: DefyxVPNRoutes.splash.route,
        builder: (context, state) => const SplashScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                child,
                const Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: DefyxNavBar(),
                ),
              ],
            ),
          );
        },
        routes: [
          GoRoute(
            path: DefyxVPNRoutes.main.route,
            pageBuilder: (context, state) => _createPageAnimation(
              const MainScreen(),
              state.pageKey,
              SlideDirection.leftToRight,
            ),
          ),
          GoRoute(
            path: DefyxVPNRoutes.settings.route,
            pageBuilder: (context, state) => _createPageAnimation(
              const SettingsScreen(),
              state.pageKey,
              SlideDirection.rightToLeft,
            ),
          ),
          GoRoute(
            path: DefyxVPNRoutes.speedTest.route,
            pageBuilder: (context, state) => _createPageAnimation(
              const SpeedTestScreen(),
              state.pageKey,
              SlideDirection.leftToRight,
            ),
          ),
        ],
      ),
    ],
  );
});

final routeInformationProvider =
    ChangeNotifierProvider<GoRouteInformationProvider>(
        (ref) => ref.watch(routerProvider).routeInformationProvider);

final currentRouteProvider =
    Provider((ref) => ref.watch(routeInformationProvider).value.uri.toString());
