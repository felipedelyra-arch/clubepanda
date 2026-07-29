import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

/// Instâncias Firebase (região das Functions = southamerica-east1).
final firebaseAuthProvider = Provider((_) => FirebaseAuth.instance);
final firestoreProvider = Provider((_) => FirebaseFirestore.instance);
final functionsProvider =
    Provider((_) => FirebaseFunctions.instanceFor(region: 'southamerica-east1'));
final storageProvider = Provider((_) => FirebaseStorage.instance);

/// Stream do estado de autenticação.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Doc do usuário logado em tempo real.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(auth.uid)
      .snapshots()
      .map((d) => d.exists ? AppUser.fromDoc(d) : null);
});

/// Promoções ativas em tempo real. Vem tudo que o dono deixou ligado — a
/// janela de validade é aplicada em [promocoesVigentesProvider].
final promotionsProvider = StreamProvider<List<Promotion>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('promotions')
      .where('ativa', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(Promotion.fromDoc).toList());
});

/// Relógio do app: emite agora e a cada 30s.
///
/// Sem isso uma oferta que vence com o app aberto continuaria na tela até o
/// Firestore emitir de novo — e ele não emite, porque nada mudou no banco.
final agoraProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

/// Promoções no ar neste instante: dentro da janela que o dono definiu.
/// Ordena por quem termina antes (nulo = sem prazo, vai pro fim).
final promocoesVigentesProvider = Provider<AsyncValue<List<Promotion>>>((ref) {
  final agora = ref.watch(agoraProvider).value ?? DateTime.now();
  return ref.watch(promotionsProvider).whenData((list) {
    final vigentes = list.where((p) => p.vigenteEm(agora)).toList();
    vigentes.sort((a, b) {
      if (a.validadeFim == null && b.validadeFim == null) return 0;
      if (a.validadeFim == null) return 1;
      if (b.validadeFim == null) return -1;
      return a.validadeFim!.compareTo(b.validadeFim!);
    });
    return vigentes;
  });
});

/// Premiações disponíveis em tempo real.
final rewardsProvider = StreamProvider<List<Reward>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('rewards')
      .snapshots()
      .map((s) => s.docs.map(Reward.fromDoc).toList());
});

/// Planos (vitrine).
final plansProvider = StreamProvider<List<Plan>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('plans')
      .snapshots()
      .map((s) => s.docs.map(Plan.fromDoc).toList());
});

/// Assinatura ativa do usuário.
final subscriptionProvider = StreamProvider<Subscription?>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('subscriptions')
      .where('userId', isEqualTo: auth.uid)
      .where('status', isEqualTo: 'active')
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : Subscription.fromDoc(s.docs.first));
});

/// Se o usuário é assinante ativo.
final isSubscriberProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).value?.ativa ?? false;
});

/// Notificações do usuário (central de avisos), mais recentes primeiro.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(auth.uid)
      .collection('notifications')
      .orderBy('criadoEm', descending: true)
      .snapshots()
      .map((s) => s.docs.map(AppNotification.fromDoc).toList());
});

/// Quantidade de notificações não lidas (badge do sino).
final unreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).value ?? const [];
  return list.where((n) => !n.lida).length;
});

/// Resgates do usuário.
final redemptionsProvider = StreamProvider<List<Redemption>>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('redemptions')
      .where('userId', isEqualTo: auth.uid)
      .snapshots()
      .map((s) => s.docs.map(Redemption.fromDoc).toList());
});

/// Quanto o sócio já economizou com os prêmios que resgatou.
/// Usa o valor congelado no resgate; se não houver, o valor atual do prêmio.
final economiaProvider = Provider<({double total, int resgates})>((ref) {
  final resgates = ref.watch(redemptionsProvider).value ?? const [];
  final premios = ref.watch(rewardsProvider).value ?? const [];

  var total = 0.0;
  for (final r in resgates) {
    if (r.valor > 0) {
      total += r.valor;
      continue;
    }
    for (final p in premios) {
      if (p.id == r.rewardId) {
        total += p.valor;
        break;
      }
    }
  }
  return (total: total, resgates: resgates.length);
});
