/**
 * Cenário 3 — abrir o painel do dono.
 *
 * O painel assina coleções inteiras, sem `limit` e sem `where`
 * (admin/src/lib/useCollection.ts:43 + as chamadas em pages/Dashboard.tsx:248-253,
 * Members.tsx:18-22, Payments.tsx:48-49). Cada abertura de página lê todos os
 * documentos das coleções que ela usa.
 *
 * Este medidor conta exatamente isso, porque é o número que vira conta no fim
 * do mês e o que decide quando o navegador do dono trava.
 *
 * Uso: node loadtest/medir-painel.js
 */
const { db, exigirEmulador, cronometrar, ms } = require("./lib");

// Preço de leitura do Firestore em southamerica-east1 (USD por documento).
// Fonte: tabela pública do Firestore; confirmar antes de citar como oficial.
const USD_POR_LEITURA = 0.06 / 100000;
const USD_BRL = 5.4;

const PAGINAS = {
  "Dashboard.tsx:248": ["users", "subscriptions", "payments", "redemptions", "promotions", "rewards"],
  "Members.tsx:18": ["users", "subscriptions", "plans", "payments", "redemptions"],
  "Payments.tsx:48": ["payments", "users"],
  "Notifications.tsx:51": ["users", "subscriptions", "notificationLogs"],
  "Rewards.tsx:33": ["rewards", "redemptions"],
};

async function contar(colecao) {
  const snap = await db.collection(colecao).count().get();
  return snap.data().count;
}

async function main() {
  exigirEmulador();
  console.log("\n=== Custo de abrir cada página do painel ===\n");

  const tamanhos = {};
  for (const col of new Set(Object.values(PAGINAS).flat())) {
    tamanhos[col] = await contar(col);
  }
  console.log("Tamanho das coleções no emulador:");
  for (const [c, n] of Object.entries(tamanhos).sort((a, b) => b[1] - a[1])) {
    console.log(`  ${c.padEnd(18)} ${n}`);
  }

  console.log("\nLeituras por abertura de página:\n");
  let pior = { pagina: "", leituras: 0 };
  for (const [pagina, cols] of Object.entries(PAGINAS)) {
    const leituras = cols.reduce((s, c) => s + (tamanhos[c] ?? 0), 0);
    if (leituras > pior.leituras) pior = { pagina, leituras };
    console.log(`  ${pagina.padEnd(24)} ${String(leituras).padStart(8)} leituras`);
  }

  // Tempo real de trazer tudo, que é o que o navegador do dono aguenta ou não.
  const [docs, t] = await cronometrar(async () => {
    let n = 0;
    for (const col of PAGINAS["Dashboard.tsx:248"]) {
      const snap = await db.collection(col).get();
      n += snap.size;
    }
    return n;
  });
  console.log(
    `\nDashboard: ${docs} documentos trazidos de verdade em ${ms(t)} (emulador local).`
  );

  const porAbertura = pior.leituras * USD_POR_LEITURA;
  console.log(
    `\nCusto da página mais cara (${pior.pagina}): ` +
      `US$ ${porAbertura.toFixed(4)} por abertura`
  );
  console.log(
    `  20 aberturas/dia x 30 dias = US$ ${(porAbertura * 600).toFixed(2)}` +
      ` (~R$ ${(porAbertura * 600 * USD_BRL).toFixed(2)}) por mês, só de olhar o painel.`
  );
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
