import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/push_service.dart';
import 'core/demo.dart';
import 'core/widgets/phone_frame.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  // Modo demo: não inicializa Firebase, usa dados fictícios (overrides).
  if (!kDemo) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(
    ProviderScope(
      overrides: kDemo ? demoOverrides : const [],
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
    return MaterialApp.router(
      title: 'Clube Panda',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) => PhoneFrame(child: child ?? const SizedBox()),
    );
  }
}
