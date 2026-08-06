import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo.dart';
import 'services/services.dart';

/// Dados de contato do restaurante.
///
/// A fonte da verdade é o doc `config/restaurante`, editado na tela de
/// Configurações do painel: o dono troca o telefone e o app pega na hora, sem
/// publicar versão nova na loja. As constantes de [RestauranteInfo.padrao] são
/// só o que aparece enquanto o doc não chegou (primeiro frame, app offline) ou
/// quando um campo está vazio no banco.
class RestauranteInfo {
  const RestauranteInfo({
    required this.nome,
    required this.telefone,
    required this.whatsapp,
    required this.endereco,
    required this.politicaPrivacidadeUrl,
    required this.termosUrl,
    required this.playStoreUrl,
    required this.appStoreUrl,
  });

  final String nome;

  /// Telefone pra ligação — DDI 55 + DDD + número, só dígitos.
  final String telefone;

  /// WhatsApp no formato wa.me — DDI 55 + DDD + número, só dígitos.
  final String whatsapp;

  /// Endereço usado na busca do Google Maps.
  final String endereco;

  /// Política de privacidade pública (exigida pelas lojas).
  final String politicaPrivacidadeUrl;

  /// Termos de uso público.
  final String termosUrl;

  /// Links das lojas (tela de update obrigatório e "indique um amigo").
  final String playStoreUrl;
  final String appStoreUrl;

  /// Valores de exemplo. Enquanto `config/restaurante` não for preenchido pelo
  /// painel, é isto que o app mostra — e os botões abrem contato fictício.
  static const padrao = RestauranteInfo(
    nome: 'Tio Panda',
    telefone: '551430000000',
    whatsapp: '5514990000000',
    endereco: 'Tio Panda restaurante',
    politicaPrivacidadeUrl: 'https://tiopanda.com.br/privacidade',
    termosUrl: 'https://tiopanda.com.br/termos',
    playStoreUrl:
        'https://play.google.com/store/apps/details?id=com.tiopanda.clube_panda',
    appStoreUrl: 'https://apps.apple.com/app/id000000000',
  );

  /// Monta a partir do doc do Firestore. Campo ausente ou em branco cai no
  /// padrão — meio preenchido é melhor que tela com buraco.
  factory RestauranteInfo.fromMap(Map<String, dynamic>? m) {
    String campo(String chave, String fallback) {
      final v = m?[chave];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      return fallback;
    }

    const p = padrao;
    return RestauranteInfo(
      nome: campo('nome', p.nome),
      telefone: campo('telefone', p.telefone),
      whatsapp: campo('whatsapp', p.whatsapp),
      endereco: campo('endereco', p.endereco),
      politicaPrivacidadeUrl:
          campo('politicaPrivacidadeUrl', p.politicaPrivacidadeUrl),
      termosUrl: campo('termosUrl', p.termosUrl),
      playStoreUrl: campo('playStoreUrl', p.playStoreUrl),
      appStoreUrl: campo('appStoreUrl', p.appStoreUrl),
    );
  }

  /// Algum contato ainda é o valor de exemplo? Usado só no aviso de debug.
  bool get contatosPendentes =>
      telefone == padrao.telefone ||
      whatsapp == padrao.whatsapp ||
      endereco == padrao.endereco;
}

/// Doc `config/restaurante` em tempo real.
final _restauranteDocProvider = StreamProvider<RestauranteInfo>((ref) {
  if (kDemo) return Stream.value(RestauranteInfo.padrao);
  return ref
      .watch(firestoreProvider)
      .doc('config/restaurante')
      .snapshots()
      .map((d) => RestauranteInfo.fromMap(d.data()));
});

/// Dados do restaurante prontos pra usar na tela, sem estado de carregando:
/// enquanto o Firestore não responde, vale o compilado. Nenhum botão de
/// contato precisa esperar rede pra desenhar.
final restauranteProvider = Provider<RestauranteInfo>((ref) {
  return ref.watch(_restauranteDocProvider).value ?? RestauranteInfo.padrao;
});
