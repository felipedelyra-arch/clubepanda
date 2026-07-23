import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

/// Instâncias Firebase (região das Functions = southamerica-east1).
final firebaseAuthProvider = Provider((_) => FirebaseAuth.instance);
final firestoreProvider = Provider((_) => FirebaseFirestore.instance);
final functionsProvider =
    Provider((_) => FirebaseFunctions.instanceFor(region: 'southamerica-east1'));

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

/// Promoções ativas em tempo real.
final promotionsProvider = StreamProvider<List<Promotion>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('promotions')
      .where('ativa', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(Promotion.fromDoc).toList());
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
