/**
 * Cenário 1 — disparo de aviso (o caminho mais caro do backend).
 *
 * Reproduz fielmente `coletarAlvos` + `gravarNaCentral` de
 * firebase/functions/src/push.ts (linhas 22-70), medindo cada etapa separada.
 * Não chama o FCM: o que trava não é o envio, é a varredura de `users` e a
 * gravação de um documento de aviso por pessoa.
 *
 * Uso: node loadtest/medir-push.js [publico]
 *      publico = "todos" (padrão) ou "assinantes"
 */
const { db, exigirEmulador, cronometrar, ms } = require("./lib");

const PUBLICO = process.argv[2] || "todos";

async function coletarAlvos(onlySubscribers) {
  const alvos = new Map();
  let leituras = 0;
  let idasAoBanco = 0;

  const somar = (uid, token) => {
    if (!uid) return;
    alvos.set(uid, { uid, token: typeof token === "string" ? token : undefined });
  };

  if (onlySubscribers) {
    const subs = await db
      .collection("subscriptions")
      .where("status", "==", "active")
      .get();
    leituras += subs.size;
    idasAoBanco += 1;

    const uids = [...new Set(subs.docs.map((d) => d.get("userId")))].filter(Boolean);
    for (let i = 0; i < uids.length; i += 30) {
      const lote = uids.slice(i, i + 30);
      if (lote.length === 0) continue;
      const users = await db.collection("users").where("uid", "in", lote).get();
      leituras += users.size;
      idasAoBanco += 1;
      users.forEach((u) => somar(u.get("uid") ?? u.id, u.get("fcmToken")));
    }
  } else {
    const users = await db.collection("users").get();
    leituras += users.size;
    idasAoBanco += 1;
    users.forEach((u) => somar(u.get("uid") ?? u.id, u.get("fcmToken")));
  }

  return { alvos: [...alvos.values()], leituras, idasAoBanco };
}

async function gravarNaCentral(alvos) {
  let commits = 0;
  for (let i = 0; i < alvos.length; i += 450) {
    const lote = db.batch();
    alvos.slice(i, i + 450).forEach((a) => {
      const ref = db.collection("users").doc(a.uid).collection("notifications").doc();
      lote.set(ref, {
        titulo: "Medição",
        corpo: "Medição de carga",
        tipo: "info",
        lida: false,
        criadoEm: new Date(),
      });
    });
    await lote.commit();
    commits += 1;
  }
  return { commits, escritas: alvos.length };
}

async function main() {
  exigirEmulador();
  const onlySubs = PUBLICO === "assinantes";
  console.log(`\n=== Disparo de aviso — público: ${PUBLICO} ===\n`);

  const [coleta, tColeta] = await cronometrar(() => coletarAlvos(onlySubs));
  console.log(`coletarAlvos()`);
  console.log(`  alvos encontrados : ${coleta.alvos.length}`);
  console.log(`  leituras Firestore: ${coleta.leituras}`);
  console.log(`  idas ao banco     : ${coleta.idasAoBanco} (sequenciais)`);
  console.log(`  tempo             : ${ms(tColeta)}`);

  const [grav, tGrav] = await cronometrar(() => gravarNaCentral(coleta.alvos));
  console.log(`\ngravarNaCentral()`);
  console.log(`  escritas          : ${grav.escritas}`);
  console.log(`  commits de lote   : ${grav.commits} (sequenciais)`);
  console.log(`  tempo             : ${ms(tGrav)}`);

  const total = tColeta + tGrav;
  console.log(`\nTOTAL: ${ms(total)}  |  timeout padrão da Function: 60000ms`);
  console.log(
    `Margem: ${((total / 60000) * 100).toFixed(1)}% do orçamento de tempo consumido.`
  );

  // Memória: os alvos ficam todos num Map até a última escrita terminar.
  const heap = process.memoryUsage().heapUsed / 1024 / 1024;
  console.log(
    `Heap do processo: ${heap.toFixed(0)}MB  |  memória padrão da Function: 256MB`
  );
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
