/**
 * Cenário 2 — corrida pelo mesmo prêmio (o fluxo principal do produto).
 *
 * Reproduz a transação de `redeemReward`
 * (firebase/functions/src/redemptions.ts:31-81) com N pessoas resgatando o
 * MESMO prêmio ao mesmo tempo — que é exatamente o que acontece quando o push
 * "🎁 Prêmio novo no Clube" chega em todos os celulares no mesmo segundo.
 *
 * O que se mede: quantas transações passam, quantas falham, e quanto o
 * documento do prêmio segura de escrita concorrente. Todas as transações
 * disputam `rewards/{id}`, então elas serializam nesse documento.
 *
 * Uso: node loadtest/medir-resgate.js [concorrentes] [estoque]
 */
const { db, exigirEmulador, cronometrar, percentis, ms } = require("./lib");

const CONCORRENTES = Number(process.argv[2] || 100);
const ESTOQUE = Number(process.argv[3] || 1000);
const REWARD_ID = `premio_teste_${Date.now()}`;

async function resgatar(uid) {
  const rewardRef = db.doc(`rewards/${REWARD_ID}`);
  return db.runTransaction(async (tx) => {
    const jaResgatou = db
      .collection("redemptions")
      .where("userId", "==", uid)
      .where("rewardId", "==", REWARD_ID)
      .limit(1);

    const [rewardSnap, jaSnap] = await Promise.all([
      tx.get(rewardRef),
      tx.get(jaResgatou),
    ]);

    if (!rewardSnap.exists) throw new Error("not-found");
    if (!jaSnap.empty) throw new Error("already-exists");

    const estoque = rewardSnap.data().estoque ?? 0;
    if (estoque <= 0) throw new Error("sem-estoque");

    tx.update(rewardRef, { estoque: estoque - 1 });
    const ref = db.collection("redemptions").doc();
    tx.set(ref, {
      userId: uid,
      rewardId: REWARD_ID,
      valor: 45,
      codigo: Math.random().toString(36).slice(2, 14).toUpperCase(),
      status: "disponivel",
      criadoEm: new Date(),
    });
    return ref.id;
  });
}

async function main() {
  exigirEmulador();
  await db.doc(`rewards/${REWARD_ID}`).set({
    titulo: "Rodízio grátis",
    valor: 45,
    estoque: ESTOQUE,
  });

  console.log(
    `\n=== Corrida pelo mesmo prêmio — ${CONCORRENTES} pessoas, estoque ${ESTOQUE} ===\n`
  );

  const latencias = [];
  const erros = {};

  const [, tTotal] = await cronometrar(async () => {
    await Promise.all(
      Array.from({ length: CONCORRENTES }, async (_, i) => {
        const uid = `u${String(i).padStart(7, "0")}`;
        try {
          const [, t] = await cronometrar(() => resgatar(uid));
          latencias.push(t);
        } catch (e) {
          const chave = e.message || String(e.code || "erro");
          erros[chave] = (erros[chave] ?? 0) + 1;
        }
      })
    );
  });

  const ok = latencias.length;
  const falhas = CONCORRENTES - ok;
  const p = percentis(latencias.length ? latencias : [0]);

  console.log(`sucesso        : ${ok}/${CONCORRENTES}`);
  console.log(
    `falhas         : ${falhas} (${((falhas / CONCORRENTES) * 100).toFixed(1)}%)`
  );
  if (falhas) console.log(`  motivos      : ${JSON.stringify(erros)}`);
  console.log(`tempo total    : ${ms(tTotal)}`);
  console.log(
    `vazão efetiva  : ${((ok / tTotal) * 1000).toFixed(1)} resgates/s ` +
      `(todos no MESMO documento de prêmio)`
  );
  console.log(
    `latência       : p50 ${ms(p.p50)} | p95 ${ms(p.p95)} | p99 ${ms(p.p99)} | máx ${ms(p.max)}`
  );

  const restante = (await db.doc(`rewards/${REWARD_ID}`).get()).get("estoque");
  const baixado = ESTOQUE - restante;
  console.log(
    `\nintegridade do estoque: baixou ${baixado}, gravou ${ok} resgates ` +
      `-> ${baixado === ok ? "OK, bate" : "DIVERGENTE"}`
  );
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
