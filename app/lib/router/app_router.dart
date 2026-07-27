import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/services.dart';
import '../core/app_prefs.dart';
import '../core/demo.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/home/home_screen.dart';
import '../features/rewards/rewards_screen.dart';
import '../features/subscription/plans_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/wallet/carteirinha_screen.dart';
import '../features/menu/menu_screen.dart';
import '../features/notifications/notifications_screen.dart';

/// Router com guarda de autenticação e de onboarding.
/// Sem onboarding visto => manda pra /onboarding. Sem sessão => /login.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final vistoOnboardingInicial = ref.read(onboardingSeenProvider);

  return GoRouter(
    initialLocation: !vistoOnboardingInicial
        ? '/onboarding'
        : (kDemo ? '/login' : '/home'),
    // Analytics de navegação (screen_view). Só fora do demo (precisa de Firebase).
    observers: [
      if (!kDemo)
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final noOnboarding = state.matchedLocation == '/onboarding';
      final vistoOnboarding = ref.read(onboardingSeenProvider);

      // Ainda não viu o tour: força o onboarding.
      if (!vistoOnboarding) return noOnboarding ? null : '/onboarding';
      // Já viu, mas está na tela de onboarding: sai dela.
      if (noOnboarding) {
        if (kDemo) return '/login';
        return authState.value != null ? '/home' : '/login';
      }

      if (kDemo) return null; // demo: sem guarda de auth, navega livre

      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';
      final signedIn = authState.value != null;

      if (!signedIn) return loggingIn ? null : '/login';
      if (loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      // Telas em foco (sem bottom nav), com botão de voltar.
      GoRoute(
          path: '/carteirinha',
          builder: (_, _) => const CarteirinhaScreen()),
      GoRoute(path: '/cardapio', builder: (_, _) => const MenuScreen()),
      GoRoute(
          path: '/configuracoes', builder: (_, _) => const SettingsScreen()),
      GoRoute(
          path: '/notificacoes',
          builder: (_, _) => const NotificationsScreen()),
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
