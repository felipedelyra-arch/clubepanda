import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo.dart';

/// Instância do Firebase Analytics.
final analyticsProvider = Provider((_) => FirebaseAnalytics.instance);

/// Registra um evento de analytics. No modo demo vira no-op.
Future<void> logEvento(
  Ref ref,
  String nome, {
  Map<String, Object>? params,
}) async {
  if (kDemo) return;
  await ref.read(analyticsProvider).logEvent(name: nome, parameters: params);
}

/// Versão pra WidgetRef (telas). No modo demo vira no-op.
Future<void> logEventoUi(
  WidgetRef ref,
  String nome, {
  Map<String, Object>? params,
}) async {
  if (kDemo) return;
  await ref.read(analyticsProvider).logEvent(name: nome, parameters: params);
}
