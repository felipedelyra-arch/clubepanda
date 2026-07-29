import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelos das coleções Firestore do Clube Panda.
/// Espelham o backend — mudou aqui, confira as rules e as Functions.

class AppUser {
  AppUser({
    required this.uid,
    required this.nome,
    required this.email,
    this.telefone = '',
    this.endereco,
    this.fotoUrl,
    this.role,
    this.nascimento,
    this.codigoIndicacao,
    this.indicacoes = 0,
  });

  final String uid;
  final String nome;
  final String email;
  final String telefone;
  final String? endereco;
  final String? fotoUrl;
  final String? role;
  final DateTime? nascimento;

  /// Código pra indicar amigos (gerado sob demanda no backend).
  final String? codigoIndicacao;

  /// Quantos amigos já foram indicados por este usuário.
  final int indicacoes;

  bool get isAdmin => role == 'admin';

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AppUser(
      uid: d.id,
      nome: m['nome'] ?? '',
      email: m['email'] ?? '',
      telefone: m['telefone'] ?? '',
      endereco: m['endereco'],
      fotoUrl: m['fotoUrl'],
      role: m['role'],
      nascimento: (m['nascimento'] as Timestamp?)?.toDate(),
      codigoIndicacao: m['codigoIndicacao'],
      indicacoes: (m['indicacoes'] ?? 0) as int,
    );
  }
}

/// Notificação (aviso/promo) exibida na central e enviada por push.
class AppNotification {
  AppNotification({
    required this.id,
    required this.titulo,
    required this.corpo,
    this.tipo = 'info',
    this.criadoEm,
    this.lida = false,
  });

  final String id;
  final String titulo;
  final String corpo;
  final String tipo; // promo | aniversario | info
  final DateTime? criadoEm;
  final bool lida;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AppNotification(
      id: d.id,
      titulo: m['titulo'] ?? '',
      corpo: m['corpo'] ?? '',
      tipo: m['tipo'] ?? 'info',
      criadoEm: (m['criadoEm'] as Timestamp?)?.toDate(),
      lida: m['lida'] ?? false,
    );
  }
}

class Plan {
  Plan({
    required this.id,
    required this.nome,
    required this.preco,
    required this.intervalo,
    this.beneficios = const [],
    this.recomendado = false,
  });

  final String id;
  final String nome;
  final double preco;
  final String intervalo; // mensal | trimestral | anual
  final List<String> beneficios;
  final bool recomendado;

  factory Plan.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Plan(
      id: d.id,
      nome: m['nome'] ?? '',
      preco: (m['preco'] ?? 0).toDouble(),
      intervalo: m['intervalo'] ?? 'mensal',
      beneficios: List<String>.from(m['beneficios'] ?? const []),
      recomendado: m['recomendado'] ?? false,
    );
  }
}

class Promotion {
  Promotion({
    required this.id,
    required this.titulo,
    required this.descricao,
    this.imagem,
    this.ativa = true,
    this.apenasAssinantes = false,
    this.validadeInicio,
    this.validadeFim,
  });

  final String id;
  final String titulo;
  final String descricao;
  final String? imagem;
  final bool ativa;
  final bool apenasAssinantes;
  /// Início da janela. Nulo = já vale.
  final DateTime? validadeInicio;

  /// Fim da janela. Nulo = não expira.
  final DateTime? validadeFim;

  /// Está no ar neste instante? Recebe o "agora" de fora pra a Home poder
  /// reavaliar num relógio (ver `agoraProvider`) — usar `DateTime.now()` aqui
  /// dentro só reavaliaria quando o Firestore emitisse.
  bool vigenteEm(DateTime agora) {
    if (!ativa) return false;
    if (validadeInicio != null && agora.isBefore(validadeInicio!)) return false;
    if (validadeFim != null && agora.isAfter(validadeFim!)) return false;
    return true;
  }

  factory Promotion.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Promotion(
      id: d.id,
      titulo: m['titulo'] ?? '',
      descricao: m['descricao'] ?? '',
      imagem: m['imagem'],
      ativa: m['ativa'] ?? true,
      apenasAssinantes: m['apenasAssinantes'] ?? false,
      validadeInicio: (m['validadeInicio'] as Timestamp?)?.toDate(),
      validadeFim: (m['validadeFim'] as Timestamp?)?.toDate(),
    );
  }
}

/// Prato do cardápio. Coleção `menu`, um doc por prato — a categoria é campo,
/// não subcoleção, pra tela inteira caber num `snapshots()` só.
class MenuItem {
  MenuItem({
    required this.id,
    required this.nome,
    this.descricao = '',
    this.preco = 0,
    this.categoria = 'Outros',
    this.imagem,
    this.destaque = false,
    this.disponivel = true,
    this.ordem = 0,
  });

  final String id;
  final String nome;
  final String descricao;

  /// Em reais. Guardado como número — quem formata é a tela.
  final double preco;
  final String categoria;
  final String? imagem;

  /// Aparece na vitrine "Destaques do cardápio" da Home.
  final bool destaque;

  /// Fora do ar sem apagar — pro dia em que acaba o peixe.
  final bool disponivel;

  /// Menor primeiro. Ordena o prato dentro da categoria, e a categoria pelo
  /// menor valor entre os pratos dela.
  final int ordem;

  String get precoFormatado =>
      'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}';

  factory MenuItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return MenuItem(
      id: d.id,
      nome: m['nome'] ?? '',
      descricao: m['descricao'] ?? '',
      preco: (m['preco'] as num?)?.toDouble() ?? 0,
      categoria: (m['categoria'] as String?)?.trim().isNotEmpty == true
          ? m['categoria'] as String
          : 'Outros',
      imagem: m['imagem'],
      destaque: m['destaque'] ?? false,
      disponivel: m['disponivel'] ?? true,
      ordem: (m['ordem'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Categoria montada em memória a partir dos pratos.
class MenuCategoria {
  const MenuCategoria({required this.nome, required this.itens});
  final String nome;
  final List<MenuItem> itens;
}

class Reward {
  Reward({
    required this.id,
    required this.titulo,
    required this.descricao,
    this.imagem,
    this.tipo = 'cupom',
    this.estoque = 0,
    this.resgatavelAte,
    this.valor = 0,
  });

  final String id;
  final String titulo;
  final String descricao;
  final String? imagem;
  final String tipo; // rodizio | prato | sobremesa | cupom
  final int estoque;

  /// Quanto o prêmio vale em reais (preço de cardápio). Alimenta o
  /// "você já economizou" na Home. Zero = não entra na conta.
  final double valor;

  /// Prazo limite pra resgatar (definido pelo dono). Nulo = sem prazo.
  final DateTime? resgatavelAte;

  /// Janela de resgate ainda aberta?
  bool noPrazoEm(DateTime agora) =>
      resgatavelAte == null || !agora.isAfter(resgatavelAte!);

  bool get noPrazo => noPrazoEm(DateTime.now());

  bool get disponivel => estoque > 0 && noPrazo;

  factory Reward.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Reward(
      id: d.id,
      titulo: m['titulo'] ?? '',
      descricao: m['descricao'] ?? '',
      imagem: m['imagem'],
      tipo: m['tipo'] ?? 'cupom',
      estoque: (m['estoque'] ?? 0) as int,
      resgatavelAte: (m['resgatavelAte'] as Timestamp?)?.toDate(),
      valor: (m['valor'] ?? 0).toDouble(),
    );
  }
}

class Redemption {
  Redemption({
    required this.id,
    required this.userId,
    required this.rewardId,
    required this.rewardTitulo,
    required this.codigo,
    required this.status,
    this.criadoEm,
    this.valor = 0,
  });

  final String id;
  final String userId;
  final String rewardId;
  final String rewardTitulo;
  final String codigo;
  final String status; // disponivel | usado | expirado
  final DateTime? criadoEm;

  /// Valor do prêmio no momento do resgate (congelado). Se zero, o app
  /// cai no valor atual do reward correspondente.
  final double valor;

  factory Redemption.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Redemption(
      id: d.id,
      userId: m['userId'] ?? '',
      rewardId: m['rewardId'] ?? '',
      rewardTitulo: m['rewardTitulo'] ?? '',
      codigo: m['codigo'] ?? '',
      status: m['status'] ?? 'disponivel',
      criadoEm: (m['criadoEm'] as Timestamp?)?.toDate(),
      valor: (m['valor'] ?? 0).toDouble(),
    );
  }
}

class Subscription {
  Subscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.status,
    this.proximaCobranca,
    this.formaPagamento,
  });

  final String id;
  final String userId;
  final String planId;
  final String status; // active | canceled | past_due
  final DateTime? proximaCobranca;
  final String? formaPagamento;

  bool get ativa => status == 'active';

  factory Subscription.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Subscription(
      id: d.id,
      userId: m['userId'] ?? '',
      planId: m['planId'] ?? '',
      status: m['status'] ?? 'canceled',
      proximaCobranca: (m['proximaCobranca'] as Timestamp?)?.toDate(),
      formaPagamento: m['formaPagamento'],
    );
  }
}
