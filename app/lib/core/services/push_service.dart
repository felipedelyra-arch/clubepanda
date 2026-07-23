import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services.dart';

/// Gerencia FCM: pede permissão, salva o token no doc do usuário e o
/// mantém atualizado. Chamado quando há usuário logado.
class PushService {
  PushService(this._ref);
  final Ref _ref;

  Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token != null) await _salvarToken(token);

    // Atualiza se o token rotacionar.
    messaging.onTokenRefresh.listen(_salvarToken);
  }

  Future<void> _salvarToken(String token) async {
    final uid = _ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await _ref
        .read(firestoreProvider)
        .doc('users/$uid')
        .set({'fcmToken': token}, SetOptions(merge: true));
  }
}

/// Provider que liga o push quando o usuário loga.
final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  ref.listen(authStateProvider, (_, next) {
    if (next.value != null) service.init();
  });
  return service;
});
