import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/services.dart';
import '../core/demo.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/home/home_screen.dart';
import '../features/rewards/rewards_screen.dart';
import '../features/subscription/plans_screen.dart';
import '../features/profile/profile_screen.dart';

/// Router com guarda de autenticação. Sem sessão => manda pra /login.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      if (kDemo) return null; // demo: sem guarda, navega livre
      final loggingIn =
          state.matchedLocation == '/login' || state.matchedLocation == '/signup';
      final signedIn = authState.value != null;

      if (!signedIn) return loggingIn ? null : '/login';
      if (loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      ShellRoute(
        builder: (_, _, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/premiacoes', builder: (_, _) => const RewardsScreen()),
          GoRoute(path: '/planos', builder: (_, _) => const PlansScreen()),
          GoRoute(path: '/perfil', builder: (_, _) => const ProfileScreen()),
        ],
      ),
    ],
  );
});

/// Refaz o redirect quando o estado de auth muda.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
}
