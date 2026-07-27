/// Dados de contato do restaurante, num único lugar.
///
/// ⚠️ PREENCHER com os dados reais do Tio Panda antes de publicar.
/// Enquanto estiverem com os valores de exemplo, os botões de contato
/// (Ligar / WhatsApp / Como chegar) abrem números/endereço fictícios.
class Restaurante {
  Restaurante._();

  static const String nome = 'Tio Panda';

  /// Telefone fixo pra ligação — formato tel: (DDI 55 + DDD + número).
  static const String telefone = '551430000000'; // TODO: telefone real

  /// WhatsApp — formato wa.me (DDI 55 + DDD + número, só dígitos).
  static const String whatsapp = '5514990000000'; // TODO: WhatsApp real

  /// Endereço usado na busca do Google Maps.
  static const String endereco = 'Tio Panda restaurante'; // TODO: endereço real

  /// Política de privacidade pública (exigida pelas lojas). PREENCHER.
  static const String politicaPrivacidadeUrl =
      'https://tiopanda.com.br/privacidade'; // TODO: URL real

  /// Termos de uso público. PREENCHER.
  static const String termosUrl =
      'https://tiopanda.com.br/termos'; // TODO: URL real

  /// Links das lojas (usados na tela de update obrigatório). PREENCHER.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.tiopanda.clube'; // TODO
  static const String appStoreUrl =
      'https://apps.apple.com/app/id000000000'; // TODO

  /// Algum contato ainda está com o valor de exemplo?
  static bool get contatosPendentes =>
      telefone.endsWith('0000') ||
      whatsapp.endsWith('0000') ||
      endereco == 'Tio Panda restaurante';
}
