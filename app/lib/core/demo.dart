import 'package:flutter_riverpod/legacy.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models/models.dart';
import 'services/services.dart';

/// Liga com: flutter run -d chrome --dart-define=DEMO=true
/// Bypassa Firebase (sem initializeApp) e injeta dados fictícios nas telas.
const bool kDemo = bool.fromEnvironment('DEMO', defaultValue: false);

/// No demo, controla se o usuário é sócio ativo (alterna as telas).
final demoIsSubscriber = StateProvider<bool>((_) => true);

final _demoUser = AppUser(
  uid: 'u_demo',
  nome: 'Ana Souza',
  email: 'ana@email.com',
  telefone: '(14) 99911-0001',
  pontos: 320,
);

final _demoPromotions = [
  Promotion(
    id: 'promo1',
    titulo: 'Rodízio com 20% OFF',
    descricao: 'Toda quarta, rodízio completo com desconto pra assinantes.',
    ativa: true,
    apenasAssinantes: true,
  ),
  Promotion(
    id: 'promo2',
    titulo: 'Temaki em dobro',
    descricao: 'Compre 1 temaki e leve 2 na sexta-feira.',
    ativa: true,
    apenasAssinantes: false,
  ),
  Promotion(
    id: 'promo3',
    titulo: 'Combo família',
    descricao: '40 peças + 2 refrigerantes por um preço especial.',
    ativa: true,
    apenasAssinantes: false,
  ),
];

final _demoRewards = [
  Reward(
    id: 'rw1',
    titulo: 'Rodízio grátis',
    descricao: 'Um rodízio completo por nossa conta.',
    tipo: 'rodizio',
    custoPontos: 500,
    estoque: 10,
  ),
  Reward(
    id: 'rw2',
    titulo: 'Sushi especial do chef',
    descricao: 'Combinado exclusivo de 12 peças.',
    tipo: 'prato',
    custoPontos: 250,
    estoque: 20,
  ),
  Reward(
    id: 'rw3',
    titulo: 'Sorvete de matchá',
    descricao: 'Sobremesa tradicional japonesa.',
    tipo: 'sobremesa',
    custoPontos: 100,
    estoque: 0,
  ),
  Reward(
    id: 'rw4',
    titulo: 'Saquê de boas-vindas',
    descricao: 'Exclusivo pra assinantes.',
    tipo: 'cupom',
    custoPontos: 0,
    estoque: 50,
    apenasAssinantes: true,
  ),
];

final _demoPlans = [
  Plan(
    id: 'p_mensal',
    nome: 'Mensal',
    preco: 49.9,
    intervalo: 'mensal',
    beneficios: ['Promoções exclusivas', 'Acúmulo de pontos', '1 sobremesa grátis/mês'],
  ),
  Plan(
    id: 'p_trimestral',
    nome: 'Trimestral',
    preco: 129.9,
    intervalo: 'trimestral',
    beneficios: ['Tudo do Mensal', 'Rodízio grátis no aniversário', 'Prioridade no delivery'],
    recomendado: true,
  ),
  Plan(
    id: 'p_anual',
    nome: 'Anual',
    preco: 499.0,
    intervalo: 'anual',
    beneficios: ['Tudo do Trimestral', '2 rodízios grátis', 'Brinde de boas-vindas'],
  ),
];

final _demoRedemptions = [
  Redemption(
    id: 'rd1',
    userId: 'u_demo',
    rewardId: 'rw2',
    rewardTitulo: 'Sushi especial do chef',
    codigo: 'A1B2C3D4E5F6',
    status: 'disponivel',
    criadoEm: DateTime.now().subtract(const Duration(days: 1)),
  ),
  Redemption(
    id: 'rd2',
    userId: 'u_demo',
    rewardId: 'rw3',
    rewardTitulo: 'Sorvete de matchá',
    codigo: '9Z8Y7X6W5V4U',
    status: 'usado',
    criadoEm: DateTime.now().subtract(const Duration(days: 9)),
  ),
];

/// Overrides do Riverpod pro modo demo — substituem os streams do Firebase.
final demoOverrides = [
  authStateProvider.overrideWith((_) => Stream<User?>.value(null)),
  currentUserProvider.overrideWith((_) => Stream.value(_demoUser)),
  promotionsProvider.overrideWith((_) => Stream.value(_demoPromotions)),
  rewardsProvider.overrideWith((_) => Stream.value(_demoRewards)),
  plansProvider.overrideWith((_) => Stream.value(_demoPlans)),
  redemptionsProvider.overrideWith((_) => Stream.value(_demoRedemptions)),
  subscriptionProvider.overrideWith((ref) {
    final ativo = ref.watch(demoIsSubscriber);
    return Stream.value(
      ativo
          ? Subscription(
              id: 's_demo',
              userId: 'u_demo',
              planId: 'p_trimestral',
              status: 'active',
              proximaCobranca: DateTime.now().add(const Duration(days: 22)),
              formaPagamento: 'cartao',
            )
          : null,
    );
  }),
];
