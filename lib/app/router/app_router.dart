import 'package:go_router/go_router.dart';
import 'package:riverpod/riverpod.dart';

import '../../modules/main/presentation/screens/main_screen.dart';
import '../../modules/splash/presentation/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/main', builder: (context, state) => const MainScreen()),
    ],
  );
});
