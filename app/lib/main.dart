import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/push_service.dart';
import 'core/connectivity.dart';
import 'core/version_gate.dart';
import 'core/demo.dart';
import 'core/app_prefs.dart';
import 'core/ui_prefs.dart';
import 'core/widgets/phone_frame.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  // Carrega as preferências antes de rodar: permite leitura síncrona.
  final prefs = await SharedPreferences.getInstance();

  // Modo demo: não inicializa Firebase, usa dados fictícios (overrides).
  if (!kDemo) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Crashlytics: captura erros de framework e assíncronos não tratados.
    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...(kDemo ? demoOverrides : const []),
      ],
      child: const ClubePandaApp(),
    ),
  );
}

class ClubePandaApp extends ConsumerWidget {
  const ClubePandaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDemo) {
      ref.watch(pushServiceProvider); // liga o FCM ao logar
    }
    final router = ref.watch(routerProvider);
    final textScale = ref.watch(textScaleProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Clube Panda',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        // Acessibilidade: aplica o tamanho de letra escolhido em todo o app.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(textScale)),
          child: PhoneFrame(
            child: ConnectivityGate(
              child: VersionGate(child: child ?? const SizedBox()),
            ),
          ),
        );
      },
    );
  }
}
