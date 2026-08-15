import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Chamada de Cloud Function com retentativa.
///
/// ## Por que isto existe
///
/// O Firestore já cuida sozinho do que é escrita direta: guarda em disco,
/// sobrevive a fechar o app e sobe quando a rede volta. **Chamada de função
/// não tem nada disso.** Cai a rede no meio e a operação simplesmente some.
///
/// São seis pontos no app — resgatar prêmio, assinar, cancelar, excluir conta,
/// aplicar indicação e gerar código de indicação — e cada um errava do mesmo
/// jeito: uma tentativa, e o erro virava texto na tela (ou, no caso da
/// indicação no cadastro, nem isso).
///
/// ## O que este helper faz e o que não faz
///
/// Faz: repete o que falhou por motivo passageiro, com espera crescente e
/// sorteio, e desiste rápido do que não adianta repetir.
///
/// Não faz: fila em disco. Fechar o app no meio ainda perde a tentativa. A
/// fila persistente é o passo seguinte, e só vale a pena depois que todas as
/// funções de escrita forem idempotentes — hoje só `redeemReward` é.
class Chamada {
  Chamada._();

  /// Tentativas no total (a primeira mais as repetições).
  static const _tentativas = 4;

  /// Espera base. Dobra a cada volta: 400ms, 800ms, 1600ms.
  static const _base = Duration(milliseconds: 400);

  static final _sorte = Random();

  /// Erros que valem repetir: a operação não aconteceu, ou não dá pra saber.
  ///
  /// Fora desta lista a repetição é inútil e só faz o sócio esperar mais para
  /// ver o mesmo erro — `permission-denied` (não é sócio) e `invalid-argument`
  /// não melhoram com insistência.
  static const _passageiros = {
    'unavailable', // servidor fora do ar ou sem rede
    'deadline-exceeded', // demorou demais
    'internal', // erro não tratado do outro lado
    'resource-exhausted', // limite momentâneo
    'aborted', // disputa; tentar de novo é exatamente o certo
    'unknown', // o SDK usa isto quando a rede morre no meio
  };

  /// Chama [nome] com [dados], repetindo o que for passageiro.
  ///
  /// ⚠️ Só use em função **idempotente** — repetir precisa ser inofensivo. Se
  /// a resposta se perde no caminho de volta, o servidor já executou, e a
  /// repetição vai executar de novo. `redeemReward` está preparada (o id do
  /// resgate é derivado do prêmio e da pessoa); as outras ainda não, e por isso
  /// [repetir] é `false` por padrão.
  /// O resultado sai como `dynamic` de propósito: o Firebase decodifica o JSON
  /// em mapas de chave `Object?`, e tipar como `Map<String, dynamic>` estoura
  /// em cast na hora de ler — erro que só apareceria rodando.
  static Future<HttpsCallableResult<dynamic>> chamar(
    FirebaseFunctions functions,
    String nome, {
    Object? dados,
    bool repetir = false,
  }) async {
    Object? ultimoErro;
    StackTrace? ultimoStack;

    for (var tentativa = 0; tentativa < _tentativas; tentativa++) {
      try {
        return await functions.httpsCallable(nome).call(dados);
      } on FirebaseFunctionsException catch (e, s) {
        ultimoErro = e;
        ultimoStack = s;
        if (!repetir || !_passageiros.contains(e.code)) rethrow;
      } catch (e, s) {
        // Falha de rede antes de virar FirebaseFunctionsException.
        ultimoErro = e;
        ultimoStack = s;
        if (!repetir) rethrow;
      }

      if (tentativa == _tentativas - 1) break;

      // Espera crescente com sorteio. O sorteio não é enfeite: sem ele, todo
      // mundo que perdeu a conexão ao mesmo tempo — que é o caso quando o
      // Wi-Fi do salão cai — tentaria de novo no mesmo instante, e o servidor
      // levaria a avalanche inteira de uma vez.
      final espera = _base * pow(2, tentativa).toDouble();
      final jitter = Duration(milliseconds: _sorte.nextInt(250));
      debugPrint('[Chamada] $nome falhou; nova tentativa em ${espera + jitter}');
      await Future<void>.delayed(espera + jitter);
    }

    Error.throwWithStackTrace(ultimoErro!, ultimoStack!);
  }
}

/// Mensagem em português para o que deu errado.
///
/// Separa "sem internet" de "servidor recusou": as duas apareciam como o mesmo
/// "Não foi possível" genérico, e a pessoa não sabia se adiantava tentar de
/// novo ou se o problema era com ela.
String mensagemDeErro(Object erro, {required String acaoFalhou}) {
  if (erro is FirebaseFunctionsException) {
    switch (erro.code) {
      case 'unavailable':
      case 'unknown':
        return 'Sem conexão com o servidor. $acaoFalhou — tente de novo quando '
            'a internet voltar.';
      case 'deadline-exceeded':
        return 'A conexão está lenta e a resposta demorou demais. '
            'Tente de novo.';
      case 'unauthenticated':
        return 'Sua sessão expirou. Entre de novo.';
      case 'permission-denied':
        return erro.message ?? 'Você não tem permissão para isso.';
      default:
        return erro.message ?? '$acaoFalhou. Tente de novo.';
    }
  }
  return '$acaoFalhou. Tente de novo.';
}
