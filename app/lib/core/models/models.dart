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
    this.pontos = 0,
    this.role,
    this.nascimento,
  });

  final String uid;
  final String nome;
  final String email;
  final String telefone;
  final String? endereco;
  final String? fotoUrl;
  final int pontos;
  final String? role;
  final DateTime? nascimento;

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
      pontos: (m['pontos'] ?? 0) as int,
      role: m['role'],
      nascimento: (m['nascimento'] as Timestamp?)?.toDate(),
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
  final DateTime? validadeInicio;
  final DateTime? validadeFim;

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

class Reward {
  Reward({
    required this.id,
    required this.titulo,
    required this.descricao,
    this.imagem,
    this.custoPontos = 0,
    this.tipo = 'cupom',
    this.estoque = 0,
    this.apenasAssinantes = false,
  });

  final String id;
  final String titulo;
  final String descricao;
  final String? imagem;
  final int custoPontos;
  final String tipo; // rodizio | prato | sobremesa | cupom
  final int estoque;
  final bool apenasAssinantes;

  bool get disponivel => estoque > 0;

  factory Reward.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Reward(
      id: d.id,
      titulo: m['titulo'] ?? '',
      descricao: m['descricao'] ?? '',
      imagem: m['imagem'],
      custoPontos: (m['custoPontos'] ?? 0) as int,
      tipo: m['tipo'] ?? 'cupom',
      estoque: (m['estoque'] ?? 0) as int,
      apenasAssinantes: m['apenasAssinantes'] ?? false,
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
  });

  final String id;
  final String userId;
  final String rewardId;
  final String rewardTitulo;
  final String codigo;
  final String status; // disponivel | usado | expirado
  final DateTime? criadoEm;

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
