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
    imagem: 'assets/images/hero.jpg',
  ),
  Promotion(
    id: 'promo2',
    titulo: 'Temaki em dobro',
    descricao: 'Compre 1 temaki e leve 2 na sexta-feira.',
    ativa: true,
    apenasAssinantes: false,
    imagem: 'assets/images/nigiri_maracuja.jpg',
  ),
  Promotion(
    id: 'promo3',
    titulo: 'Combo família',
    descricao: '40 peças + 2 refrigerantes por um preço especial.',
    ativa: true,
    apenasAssinantes: false,
    imagem: 'assets/images/combinado.jpg',
  ),
];

/// Destaques do cardápio (fotos reais) — vitrine na Home.
final demoDestaques = <DishHighlight>[
  DishHighlight(
      nome: 'Combinado especial',
      preco: 'R\$ 89,90',
      imagem: 'assets/images/combinado_box.jpg'),
  DishHighlight(
      nome: 'Salmão grelhado',
      preco: 'R\$ 54,90',
      imagem: 'assets/images/salmao.jpg'),
  DishHighlight(
      nome: 'Sashimi premium',
      preco: 'R\$ 62,00',
      imagem: 'assets/images/sashimi.jpg'),
  DishHighlight(
      nome: 'Strogonoff da casa',
      preco: 'R\$ 44,90',
      imagem: 'assets/images/strogonoff.jpg'),
  DishHighlight(
      nome: 'Burguer Panda',
      preco: 'R\$ 39,90',
      imagem: 'assets/images/burger.jpg'),
  DishHighlight(
      nome: 'Filé gratinado',
      preco: 'R\$ 58,00',
      imagem: 'assets/images/file_gratinado.jpg'),
];

/// Prato de exemplo pra vitrine do cardápio.
class DishHighlight {
  const DishHighlight(
      {required this.nome, required this.preco, required this.imagem});
  final String nome;
  final String preco;
  final String imagem;
}

/// ---------- Cardápio (exemplo, com fotos) ----------
class MenuItem {
  const MenuItem(
      {required this.nome,
      required this.descricao,
      required this.preco,
      required this.imagem});
  final String nome;
  final String descricao;
  final String preco;
  final String imagem;
}

class MenuCategoria {
  const MenuCategoria({required this.nome, required this.itens});
  final String nome;
  final List<MenuItem> itens;
}

final demoCardapio = <MenuCategoria>[
  MenuCategoria(nome: 'Combinados & Sushi', itens: const [
    MenuItem(
        nome: 'Combinado especial',
        descricao: '20 peças variadas: sashimi, uramaki e niguiri.',
        preco: 'R\$ 89,90',
        imagem: 'assets/images/combinado_box.jpg'),
    MenuItem(
        nome: 'Combinado do chef',
        descricao: 'Seleção do dia feita pelo sushiman.',
        preco: 'R\$ 99,90',
        imagem: 'assets/images/combinado_chef.jpg'),
    MenuItem(
        nome: 'Sashimi premium',
        descricao: 'Fatias generosas de salmão fresco.',
        preco: 'R\$ 62,00',
        imagem: 'assets/images/sashimi.jpg'),
    MenuItem(
        nome: 'Niguiri de maracujá',
        descricao: 'Salmão maçaricado com toque de maracujá.',
        preco: 'R\$ 34,90',
        imagem: 'assets/images/nigiri_maracuja.jpg'),
  ]),
  MenuCategoria(nome: 'Salmão', itens: const [
    MenuItem(
        nome: 'Salmão grelhado',
        descricao: 'Ao molho da casa, acompanha arroz.',
        preco: 'R\$ 54,90',
        imagem: 'assets/images/salmao.jpg'),
    MenuItem(
        nome: 'Salmão no purê',
        descricao: 'Filé grelhado sobre purê rústico e cogumelos.',
        preco: 'R\$ 58,90',
        imagem: 'assets/images/salmao_pure.jpg'),
  ]),
  MenuCategoria(nome: 'Pratos quentes', itens: const [
    MenuItem(
        nome: 'Strogonoff da casa',
        descricao: 'Carne, arroz e batata palha.',
        preco: 'R\$ 44,90',
        imagem: 'assets/images/strogonoff.jpg'),
    MenuItem(
        nome: 'Filé gratinado',
        descricao: 'Filé com queijo gratinado, fritas e refil.',
        preco: 'R\$ 58,00',
        imagem: 'assets/images/file_gratinado.jpg'),
  ]),
  MenuCategoria(nome: 'Lanches', itens: const [
    MenuItem(
        nome: 'Burguer Panda',
        descricao: 'Pão crocante, queijo derretido e fritas.',
        preco: 'R\$ 39,90',
        imagem: 'assets/images/burger.jpg'),
  ]),
];

final _demoRewards = [
  Reward(
    id: 'rw1',
    titulo: 'Rodízio grátis',
    descricao: 'Um rodízio completo por nossa conta.',
    tipo: 'rodizio',
    custoPontos: 500,
    estoque: 10,
    imagem: 'assets/images/reward_rodizio.jpg',
  ),
  Reward(
    id: 'rw2',
    titulo: 'Sushi especial do chef',
    descricao: 'Combinado exclusivo de 12 peças.',
    tipo: 'prato',
    custoPontos: 250,
    estoque: 20,
    imagem: 'assets/images/reward_sushi.jpg',
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
    titulo: 'Combo delivery grátis',
    descricao: 'Uma entrega por nossa conta. #PandaLovers',
    tipo: 'cupom',
    custoPontos: 0,
    estoque: 50,
    apenasAssinantes: true,
    imagem: 'assets/images/reward_delivery.jpg',
  ),
];

// Plano único, baratinho — cabe no bolso de todo mundo.
final _demoPlans = [
  Plan(
    id: 'p_mensal',
    nome: 'Clube Panda',
    preco: 4.90,
    intervalo: 'mês',
    beneficios: [
      'Descontos e promoções exclusivas todo mês',
      'Junte pontos e troque por comida',
      'Sobremesa grátis no seu aniversário',
      'Sem fidelidade — cancele quando quiser',
    ],
    recomendado: true,
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
              planId: 'p_mensal',
              status: 'active',
              proximaCobranca: DateTime.now().add(const Duration(days: 22)),
              formaPagamento: 'cartao',
            )
          : null,
    );
  }),
];
