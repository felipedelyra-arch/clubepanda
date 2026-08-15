/**
 * Corretude da exclusão de conta retomável (functions/src/account.ts).
 *
 * São sete etapas em quatro sistemas, sem transação que as cubra. O que se
 * testa aqui é o que a LGPD e as lojas cobram: que nada sobre para trás, e que
 * uma parada no meio seja retomável em vez de virar conta meio apagada.
 *
 * Precisa dos emuladores de Firestore E Auth:
 *   cd firebase && firebase emulators:start --only firestore,auth
 *
 * Uso: node loadtest/verificar-exclusao.js
 */
const path = require("path");
const { admin, db, exigirEmulador } = require("./lib");

process.env.FIREBASE_AUTH_EMULATOR_HOST =
  process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";

const auth = admin.auth();

let falhas = 0;
function checar(nome, condicao, detalhe = "") {
  const ok = Boolean(condicao);
  if (!ok) falhas++;
  console.log(`  ${ok ? "OK    " : "FALHOU"} ${nome}${detalhe ? `  (${detalhe})` : ""}`);
}

const UID = "socio_a_excluir";
const CODIGO_SOCIO = "A2B3C4";
const CODIGO_INDICACAO = "XYZ123";

async function semearConta() {
  try {
    await auth.deleteUser(UID);
  } catch {
    // Não existia.
  }
  await auth.createUser({ uid: UID, email: "excluir@teste.local" });

  await db.doc(`users/${UID}`).set({
    uid: UID,
    nome: "Sócio de Teste",
    email: "excluir@teste.local",
    codigoSocio: CODIGO_SOCIO,
    codigoIndicacao: CODIGO_INDICACAO,
  });
  await db.doc(`socioCodes/${CODIGO_SOCIO}`).set({ uid: UID });
  await db.doc(`referralCodes/${CODIGO_INDICACAO}`).set({ uid: UID });
  await db.doc(`subscriptions/sub_${UID}`).set({ userId: UID, status: "canceled" });

  // Central de avisos grande de propósito: passa dos 500 de um batch único, que
  // era o limite em que a versão anterior estourava.
  for (let i = 0; i < 600; i += 450) {
    const b = db.batch();
    for (let j = i; j < Math.min(i + 450, 600); j++) {
      b.set(db.doc(`users/${UID}/notifications/n${j}`), { titulo: `Aviso ${j}` });
    }
    await b.commit();
  }

  // Resgates acima de 500, mesma razão.
  for (let i = 0; i < 550; i += 450) {
    const b = db.batch();
    for (let j = i; j < Math.min(i + 450, 550); j++) {
      b.set(db.doc(`redemptions/r${j}_${UID}`), { userId: UID, codigo: `C${j}` });
    }
    await b.commit();
  }
  await db.doc(`exclusoes/${UID}`).delete().catch(() => undefined);
}

async function sobrouAlgo() {
  const [perfil, socio, indicacao, subs, resg, notif] = await Promise.all([
    db.doc(`users/${UID}`).get(),
    db.doc(`socioCodes/${CODIGO_SOCIO}`).get(),
    db.doc(`referralCodes/${CODIGO_INDICACAO}`).get(),
    db.collection("subscriptions").where("userId", "==", UID).count().get(),
    db.collection("redemptions").where("userId", "==", UID).count().get(),
    db.collection(`users/${UID}/notifications`).count().get(),
  ]);
  let login = true;
  try {
    await auth.getUser(UID);
  } catch {
    login = false;
  }
  return {
    perfil: perfil.exists,
    socio: socio.exists,
    indicacao: indicacao.exists,
    subs: subs.data().count,
    resgates: resg.data().count,
    notificacoes: notif.data().count,
    login,
  };
}

async function main() {
  exigirEmulador();
  const { executarExclusao } = require(
    path.join(__dirname, "..", "firebase", "functions", "lib", "account")
  );

  console.log("\n=== Exclusão de conta ===\n");

  // -------------------------------------------------------------------------
  console.log("1. Exclusão completa não deixa resíduo");
  await semearConta();
  const antes = await sobrouAlgo();
  checar(
    "semeado",
    antes.perfil && antes.resgates === 550 && antes.notificacoes === 600 && antes.login,
    `resgates=${antes.resgates} avisos=${antes.notificacoes}`
  );

  await executarExclusao(UID);
  const d = await sobrouAlgo();

  checar("perfil apagado", !d.perfil);
  checar("código de sócio apagado", !d.socio);
  checar("código de indicação apagado", !d.indicacao);
  checar("assinaturas apagadas", d.subs === 0, `${d.subs}`);
  checar("550 resgates apagados (passa dos 500 de um batch)", d.resgates === 0, `${d.resgates}`);
  checar("600 avisos apagados", d.notificacoes === 0, `${d.notificacoes}`);
  checar("login removido", !d.login);
  checar(
    "marcado como concluído",
    (await db.doc(`exclusoes/${UID}`).get()).get("etapa") === 7
  );

  // -------------------------------------------------------------------------
  console.log("\n2. Parou no meio: chamar de novo termina o serviço");
  await semearConta();
  // Simula a queda: o controle diz que só as 3 primeiras etapas passaram, e o
  // estado do banco é o que existiria nesse ponto.
  await db.doc(`exclusoes/${UID}`).set({ uid: UID, etapa: 3 });
  await db.collection("subscriptions").doc(`sub_${UID}`).delete();
  const parcial = await sobrouAlgo();
  checar(
    "estado parcial montado: perfil de pé, assinatura já fora",
    parcial.perfil && parcial.subs === 0 && parcial.login
  );

  await executarExclusao(UID);
  const fim = await sobrouAlgo();
  checar("retomou e apagou o perfil", !fim.perfil);
  checar("retomou e apagou os índices", !fim.socio && !fim.indicacao);
  checar("retomou e removeu o login", !fim.login);

  // -------------------------------------------------------------------------
  console.log("\n3. Repetir a exclusão de uma conta já apagada não estoura");
  {
    let erro = null;
    try {
      await executarExclusao(UID);
    } catch (e) {
      erro = e;
    }
    checar("segunda passada é silenciosa", erro === null, erro ? String(erro) : "");
  }

  console.log(`\n${falhas === 0 ? "PASSOU — todos os casos" : `FALHOU em ${falhas} caso(s)`}`);
  process.exit(falhas === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
