import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/push_service.dart';
import 'core/services/fila_pendentes.dart';
import 'core/connectivity.dart';
import 'core/version_gate.dart';
import 'core/demo.dart';
import 'core/app_prefs.dart';
import 'core/ui_prefs.dart';
import 'core/widgets/phone_frame.dart';
import 'core/widgets/splash_gate.dart';
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

    // Cache em disco, explícito, antes de qualquer uso do Firestore.
    //
    // ⚠️ No Android e no iOS isto já é o padrão. **Na web não é**: com
    // `persistenceEnabled` em `null`, o cloud_firestore_web cai em
    // `memoryLocalCache` (cloud_firestore_web/lib/cloud_firestore_web.dart) —
    // sem cache em disco e sem fila de escrita que sobreviva a recarregar a
    // página. É esse o build que roda em pandavip-app.web.app.
    //
    // Com isto ligado, o app abre mostrando os últimos dados mesmo sem
    // internet, e uma escrita feita offline fica guardada e sobe sozinha
    // quando a conexão volta.
    //
    // `WebPersistentMultipleTabManager`: no modo padrão (aba única) a SEGUNDA
    // aba aberta no mesmo navegador não consegue a trava do IndexedDB e falha.
    // O dono abre o painel e o app lado a lado — isso ia acontecer com ele.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      webPersistentTabManager: WebPersistentMultipleTabManager(),
    );
    // App Check: prova ao Firebase que a chamada veio deste app, e não de um
    // script com a chave de API copiada do APK. Enquanto a imposição estiver
    // desligada no console, o token é enviado e ignorado — instalar agora não
    // derruba ninguém, e é pré-requisito pra poder impor depois.
    //
    // Web fica de fora de propósito: lá o provedor é reCAPTCHA, que exige uma
    // chave de site que ainda não foi criada. Sem ela, `activate` estoura.
    if (!kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kReleaseMode
            ? const AndroidPlayIntegrityProvider()
            : const AndroidDebugProvider(),
        providerApple: kReleaseMode
            ? const AppleAppAttestProvider()
            : const AppleDebugProvider(),
      );
    }
    // Crashlytics: captura erros de framework e assíncronos não tratados.
    // Não existe no web (o pacote só tem Android/iOS) — tocar na instância lá
    // estoura antes do runApp e deixa a página em branco.
    if (!kIsWeb) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
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
      // Liga a fila de chamadas pendentes. Precisa ser observada aqui: o
      // provider é preguiçoso, e sem alguém olhando ele só nasceria quando
      // alguma tela enfileirasse algo — ou seja, nunca drenaria o que ficou da
      // sessão anterior.
      ref.watch(filaPendentesProvider);
    }
    final router = ref.watch(routerProvider);
    final textScale = ref.watch(textScaleProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'PandaVip',
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
            // SplashGate por fora dos outros portões: o banner de offline e a
            // trava de versão não devem piscar por baixo da abertura.
            child: SplashGate(
              child: ConnectivityGate(
                child: VersionGate(child: child ?? const SizedBox()),
              ),
            ),
          ),
        );
      },
    );
  }
}
