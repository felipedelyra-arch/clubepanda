import 'package:flutter_test/flutter_test.dart';
import 'package:clube_panda/core/models/models.dart';
import 'package:clube_panda/core/restaurante.dart';

void main() {
  group('Reward.disponivel / noPrazo', () {
    Reward reward({int estoque = 5, DateTime? ate}) => Reward(
          id: 'x',
          titulo: 'Prêmio',
          descricao: '',
          estoque: estoque,
          resgatavelAte: ate,
        );

    test('sem estoque não fica disponível', () {
      expect(reward(estoque: 0).disponivel, isFalse);
    });

    test('com estoque e sem prazo fica disponível', () {
      final r = reward();
      expect(r.noPrazo, isTrue);
      expect(r.disponivel, isTrue);
    });

    test('prazo no futuro continua disponível', () {
      final r = reward(ate: DateTime.now().add(const Duration(hours: 2)));
      expect(r.noPrazo, isTrue);
      expect(r.disponivel, isTrue);
    });

    test('prazo no passado não fica disponível', () {
      final r = reward(ate: DateTime.now().subtract(const Duration(hours: 1)));
      expect(r.noPrazo, isFalse);
      expect(r.disponivel, isFalse);
    });

    test('estoque ok mas prazo vencido = indisponível', () {
      final r = reward(
          estoque: 10, ate: DateTime.now().subtract(const Duration(days: 1)));
      expect(r.disponivel, isFalse);
    });
  });

  test('contatos de exemplo são marcados como pendentes', () {
    // Enquanto os placeholders não forem trocados, o app sabe que faltam dados.
    expect(Restaurante.contatosPendentes, isTrue);
  });
}
