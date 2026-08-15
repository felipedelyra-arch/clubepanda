/**
 * Concorrência nos caminhos que NÃO são o resgate.
 *
 * O resgate já tem `verificar-resgate.js` e `medir-resgate.js`. Aqui vão as
 * outras perguntas de "e se duas pessoas fizerem isso ao mesmo tempo":
 *
 *   1. muita gente criando conta no mesmo instante;
 *   2. muita gente usando o MESMO código de indicação (uma pessoa divulga o
 *      código dela e o grupo inteiro se cadastra junto);
 *   3. muita gente editando o próprio perfil ao mesmo tempo;
 *   4. a MESMA pessoa tocando duas vezes no botão de indicação.
 *
 * O que se procura é documento disputado: no Firestore, escrita concorrente só
 * enfileira quando cai na MESMA linha. Escrita em documentos diferentes não
 * disputa nada, por mais gente que seja.
 *
 * Uso: node loadtest/verificar-concorrencia.js [pessoas]
 */
const path = require("path");
const { db, exigirEmulador, cronometrar, percentis, ms } = require("./lib");

const { garantirCodigoSocio } = require(
  path.join(__dirname, "..", "firebase", "functions", "lib", "lib", "codigoSocio")
);

const PESSOAS = Number(process.argv[2] || 100);

let falhas = 0;
function checar(nome, condicao, detalhe = "") {
  const ok = Boolean(condicao);
  if (!ok) falhas++;
  console.log(`  ${ok ? "OK    " : "FALHOU"} ${nome}${detalhe ? `  (${detalhe})` : ""}`);
}

const uid = (i) => `cc${String(i).padStart(6, "0")}`;

/** Roda [fn] para N pessoas ao mesmo tempo e resume o resultado. */
async function simultaneo(n, fn) {
  const latencias = [];
  const erros = {};
  const [, total] = await cronometrar(async () => {
    await Promise.all(
      Array.from({ length: n }, async (_, i) => {
        try {
          const [, t] = await cronometrar(() => fn(i));
          latencias.push(t);
        } catch (e) {
          const chave = (e.message || String(e.code)).slice(0, 45);
          erros[chave] = (erros[chave] ?? 0) + 1;
        }
      })
    );
  });
  return { ok: latencias.length, erros, total, p: percentis(latencias.length ? latencias : [0]) };
}

async function limpar() {
  for (const col of ["users", "socioCodes", "referralCodes"]) {
    const snap = await db.collection(col).get();
    for (let i = 0; i < snap.size; i += 450) {
      const b = db.batch();
      snap.docs.slice(i, i + 450).forEach((d) => b.delete(d.ref));
      await b.commit();
    }
  }
}

async function main() {
  exigirEmulador();
  console.log(`\n=== Concorrência — ${PESSOAS} pessoas ao mesmo tempo ===\n`);
  await limpar();

  // -------------------------------------------------------------------------
  console.log("1. Cadastro: criar perfil e gerar código de carteirinha");
  {
    const r = await simultaneo(PESSOAS, async (i) => {
      const u = uid(i);
      await db.doc(`users/${u}`).set({
        uid: u,
        nome: `Sócio ${i}`,
        email: `s${i}@teste.local`,
        criadoEm: new Date(),
      });
      return garantirCodigoSocio(u);
    });

    checar(`${PESSOAS} cadastros concluídos`, r.ok === PESSOAS, `${r.ok}`);
    if (Object.keys(r.erros).length) console.log(`    erros: ${JSON.stringify(r.erros)}`);

    const perfis = await db.collection("users").select("codigoSocio").get();
    const codigos = perfis.docs.map((d) => d.get("codigoSocio")).filter(Boolean);
    checar("todo mundo saiu com código", codigos.length === PESSOAS, `${codigos.length}`);
    checar(
      "nenhum código repetido",
      new Set(codigos).size === codigos.length,
      `${new Set(codigos).size} únicos de ${codigos.length}`
    );
    console.log(
      `    tempo ${ms(r.total)} | p50 ${ms(r.p.p50)} | p95 ${ms(r.p.p95)} | máx ${ms(r.p.max)}`
    );
  }

  // -------------------------------------------------------------------------
  console.log("\n2. Editar o próprio perfil, todo mundo junto");
  {
    const r = await simultaneo(PESSOAS, (i) =>
      db.doc(`users/${uid(i)}`).set(
        { telefone: "14999990000", endereco: `Rua ${i}` },
        { merge: true }
      )
    );
    checar(`${PESSOAS} edições sem erro`, r.ok === PESSOAS, `${r.ok}`);
    console.log(`    tempo ${ms(r.total)} | p95 ${ms(r.p.p95)}`);
    console.log("    (documentos diferentes: não há disputa, e não deveria haver mesmo)");
  }

  // -------------------------------------------------------------------------
  console.log("\n3. TODO MUNDO usando o MESMO código de indicação");
  console.log("   (uma pessoa divulga o código dela e o grupo se cadastra junto —");
  console.log("    aqui o contador do indicador é UM documento só, disputado por todos)");
  {
    const padrinho = "cc_padrinho";
    await db.doc(`users/${padrinho}`).set({ uid: padrinho, indicacoes: 0 });
    await db.doc("referralCodes/CONVITE").set({ uid: padrinho });

    const r = await simultaneo(PESSOAS, async (i) => {
      const u = uid(i);
      const meu = db.doc(`users/${u}`);
      if ((await meu.get()).get("indicadoPor")) throw new Error("already-exists");
      const lookup = await db.doc("referralCodes/CONVITE").get();
      if (!lookup.exists) throw new Error("not-found");
      await meu.set(
        { indicadoPor: "CONVITE", indicadoPorUid: padrinho },
        { merge: true }
      );
      await db.doc(`users/${padrinho}`).set(
        { indicacoes: require("./lib").admin.firestore.FieldValue.increment(1) },
        { merge: true }
      );
    });

    checar(`${PESSOAS} indicações aceitas`, r.ok === PESSOAS, `${r.ok}`);
    if (Object.keys(r.erros).length) console.log(`    erros: ${JSON.stringify(r.erros)}`);

    const contador = (await db.doc(`users/${padrinho}`).get()).get("indicacoes");
    checar(
      "contador do indicador bate exatamente",
      contador === PESSOAS,
      `contou ${contador}, esperado ${PESSOAS}`
    );
    console.log(`    tempo ${ms(r.total)} | p50 ${ms(r.p.p50)} | p95 ${ms(r.p.p95)}`);
  }

  // -------------------------------------------------------------------------
  console.log("\n4. A MESMA pessoa gerando código de indicação em toque duplo");
  {
    const { randomUUID } = require("crypto");
    const u = uid(0);

    const gerar = async () => {
      const userRef = db.doc(`users/${u}`);
      const snap = await userRef.get();
      const jaTem = snap.get("codigoIndicacao");
      if (jaTem) return jaTem;
      for (let i = 0; i < 5; i++) {
        const cand = randomUUID().replace(/-/g, "").slice(0, 6).toUpperCase();
        const lookupRef = db.doc(`referralCodes/${cand}`);
        const ok = await db.runTransaction(async (tx) => {
          const [existe, atual] = await Promise.all([tx.get(lookupRef), tx.get(userRef)]);
          if (atual.get("codigoIndicacao")) return atual.get("codigoIndicacao");
          if (existe.exists) return null;
          tx.set(lookupRef, { uid: u });
          tx.set(userRef, { codigoIndicacao: cand }, { merge: true });
          return cand;
        });
        if (ok) return ok;
      }
      throw new Error("sem-codigo");
    };

    const [a, b, c] = await Promise.all([gerar(), gerar(), gerar()]);
    checar("os três toques devolvem o mesmo código", a === b && b === c, `${a}/${b}/${c}`);

    const gravado = (await db.doc(`users/${u}`).get()).get("codigoIndicacao");
    checar("o código gravado é esse mesmo", gravado === a, `${gravado}`);
  }

  await limpar();
  console.log(`\n${falhas === 0 ? "PASSOU — todos os casos" : `FALHOU em ${falhas} caso(s)`}`);
  process.exit(falhas === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
