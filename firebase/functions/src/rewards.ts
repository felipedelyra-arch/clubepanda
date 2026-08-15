import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { db } from "./lib/admin";
import { sincronizarPool, contarLivres } from "./lib/cupons";

/**
 * Gatilhos que mantêm o estoque do prêmio.
 *
 * Dois campos, com donos diferentes — é isso que evita laço entre eles:
 *
 *   `estoqueAlvo`  quanto o dono QUER que exista. Só o painel escreve.
 *   `estoque`      quantos ainda estão livres. Só [estoqueDoPremio] escreve.
 *
 * Reservar um cupom faz [estoqueDoPremio] reescrever `estoque` no prêmio, o
 * que dispara [sincronizarCupons] — que não faz nada, porque `estoqueAlvo`
 * continua igual. Sem a separação, um gatilho alimentaria o outro para sempre.
 */

/**
 * O dono mudou a quantidade: acerta o pool de cupons.
 *
 * Prêmio antigo, criado antes dos cupons existirem, não tem `estoqueAlvo`.
 * Nesse caso o valor de `estoque` que já estava lá vira o alvo — assim o
 * cadastro que o dono fez continua valendo, sem migração manual.
 */
export const sincronizarCupons = onDocumentWritten("rewards/{rewardId}", async (event) => {
  const antes = event.data?.before;
  const depois = event.data?.after;
  const rewardId = event.params.rewardId;

  // Prêmio apagado: os cupons vão junto (subcoleção não some sozinha).
  if (!depois?.exists) {
    await db.recursiveDelete(db.doc(`rewards/${rewardId}`));
    logger.info("Prêmio removido; cupons apagados.", { rewardId });
    return;
  }

  const alvoDepois = depois.get("estoqueAlvo") as number | undefined;
  const alvoAntes = antes?.exists ? (antes.get("estoqueAlvo") as number | undefined) : undefined;

  // Sem `estoqueAlvo`: prêmio de antes desta mudança. Adota o `estoque` atual.
  const alvo = alvoDepois ?? (depois.get("estoque") as number | undefined) ?? 0;

  // Nada a fazer quando o alvo não mudou. É esta guarda que impede o laço com
  // o gatilho de baixo, que escreve `estoque` a cada resgate.
  if (antes?.exists && alvoDepois === alvoAntes && alvoDepois !== undefined) return;

  const n = Math.max(0, Math.floor(Number(alvo) || 0));
  await sincronizarPool(rewardId, n);

  // `estoqueAlvo` fica gravado inclusive para o prêmio antigo, para a próxima
  // passada do gatilho reconhecer que já está sincronizado.
  await db.doc(`rewards/${rewardId}`).set(
    { estoqueAlvo: n, estoque: await contarLivres(rewardId) },
    { merge: true }
  );
  logger.info("Pool de cupons sincronizado.", { rewardId, alvo: n });
});

/**
 * Um cupom mudou de estado: recalcula o `estoque` que o app mostra.
 *
 * Recontar, e não `increment(-1)`: gatilho do Firestore entrega **pelo menos
 * uma vez**, então uma entrega repetida descontaria duas vezes do estoque.
 * Contar de novo dá o mesmo resultado por mais vezes que rode.
 *
 * Roda fora do caminho do cliente de propósito. Vários resgates simultâneos
 * fazem várias entregas escreverem o mesmo documento de prêmio — é a fila que
 * tiramos do resgate. Aqui ela é inofensiva: ninguém está esperando, e o
 * atraso aparece como um número de estoque alguns segundos atrasado.
 */
export const estoqueDoPremio = onDocumentWritten(
  "rewards/{rewardId}/cupons/{cupomId}",
  async (event) => {
    const rewardId = event.params.rewardId;
    const premio = db.doc(`rewards/${rewardId}`);
    if (!(await premio.get()).exists) return; // prêmio apagado no meio

    await premio.set({ estoque: await contarLivres(rewardId) }, { merge: true });
  }
);
