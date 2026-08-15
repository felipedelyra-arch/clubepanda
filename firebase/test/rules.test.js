/**
 * Teste das Firestore Security Rules contra o emulador.
 *
 * Existe por causa do commit `11df0cd`, que trocou a regra de `users` por uma
 * lista branca de campos e nunca rodou em runtime. Lista branca incompleta não
 * dá erro de deploy: ela quebra em silêncio, na hora do cadastro do cliente.
 *
 * Cada caso positivo aqui copia LITERALMENTE os campos de um ponto de escrita
 * do app. Quando alguém acrescentar um campo numa dessas telas sem pôr na
 * lista, é este arquivo que aponta o dedo.
 *
 * Rodar:  cd firebase && npm test        (com o emulador do Firestore no ar)
 */
const { test, before, after, beforeEach, describe } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
// As bibliotecas moram em functions/node_modules — não há um segundo
// node_modules só para os testes.
const mod = (nome) =>
  require(path.join(__dirname, "..", "functions", "node_modules", nome));

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = mod("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteField,
  serverTimestamp,
  Timestamp,
  setLogLevel,
} = mod("firebase/firestore");

const UID = "socio_teste";
const OUTRO = "outro_socio";
let env;

before(async () => {
  setLogLevel("error"); // sem o ruído de "permission denied" esperado
  env = await initializeTestEnvironment({
    projectId: "pandavip-rules-test",
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules: fs.readFileSync(path.join(__dirname, "..", "firestore.rules"), "utf8"),
    },
  });
});

after(async () => {
  if (env) await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

/** Cliente do próprio sócio. */
const eu = () => env.authenticatedContext(UID).firestore();
/** Cliente admin (custom claim role=admin). */
const admin = () => env.authenticatedContext("chefe", { role: "admin" }).firestore();
/** Cliente deslogado. */
const anonimo = () => env.unauthenticatedContext().firestore();

/** Semeia um doc ignorando as rules (é o que o backend faria). */
async function semRegras(fn) {
  await env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

// ---------------------------------------------------------------------------
// users — os pontos de escrita reais do app
// ---------------------------------------------------------------------------

describe("users: escritas que o app faz hoje", () => {
  test("signup_screen.dart:116 — cria o perfil no cadastro", async () => {
    await assertSucceeds(
      setDoc(
        doc(eu(), "users", UID),
        {
          nome: "Felipe",
          email: "felipe@teste.local",
          telefone: "14999990000",
          nascimento: Timestamp.fromDate(new Date(1990, 0, 1)),
          criadoEm: serverTimestamp(),
        },
        { merge: true }
      )
    );
  });

  test("auth_perfil.dart:27 — garantirPerfil depois do login social", async () => {
    await assertSucceeds(
      setDoc(
        doc(eu(), "users", UID),
        {
          uid: UID,
          nome: "Felipe do Google",
          email: "felipe@gmail.com",
          fotoUrl: "https://exemplo/foto.jpg",
          criadoEm: serverTimestamp(),
        },
        { merge: true }
      )
    );
  });

  test("completar_perfil_screen.dart:83 — completa o cadastro", async () => {
    await semRegras((db) => setDoc(doc(db, "users", UID), { uid: UID }));
    await assertSucceeds(
      setDoc(
        doc(eu(), "users", UID),
        {
          telefone: "14999990000",
          nascimento: Timestamp.fromDate(new Date(1990, 0, 1)),
        },
        { merge: true }
      )
    );
  });

  test("settings_screen.dart:857 — edita os dados pessoais", async () => {
    await semRegras((db) => setDoc(doc(db, "users", UID), { uid: UID, nome: "Antigo" }));
    await assertSucceeds(
      updateDoc(doc(eu(), "users", UID), {
        nome: "Felipe Maestrello",
        telefone: "14988887777",
        endereco: "Rua X, 10",
        nascimento: null,
      })
    );
  });

  test("profile_screen.dart:244 — troca a foto de perfil", async () => {
    await semRegras((db) => setDoc(doc(db, "users", UID), { uid: UID }));
    await assertSucceeds(
      updateDoc(doc(eu(), "users", UID), { fotoUrl: "https://exemplo/nova.jpg" })
    );
  });

  test("push_service.dart:51 — salva o token de push", async () => {
    await semRegras((db) => setDoc(doc(db, "users", UID), { uid: UID }));
    await assertSucceeds(
      setDoc(doc(eu(), "users", UID), { fcmToken: "tok_abc" }, { merge: true })
    );
  });

  test("push_service.dart:42 — apaga o token ao desligar avisos", async () => {
    await semRegras((db) =>
      setDoc(doc(db, "users", UID), { uid: UID, fcmToken: "tok_abc" })
    );
    await assertSucceeds(
      setDoc(doc(eu(), "users", UID), { fcmToken: deleteField() }, { merge: true })
    );
  });

  test("escrita parcial NÃO pode apagar campo que só o backend grava", async () => {
    await semRegras((db) =>
      setDoc(doc(db, "users", UID), {
        uid: UID,
        codigoSocio: "A2B3C4",
        stripeCustomerId: "cus_123",
      })
    );
    await assertSucceeds(
      setDoc(doc(eu(), "users", UID), { nome: "Novo nome" }, { merge: true })
    );
    // `withSecurityRulesDisabled` não repassa o retorno do callback — o valor
    // sai por variável.
    let depois;
    await env.withSecurityRulesDisabled(async (ctx) => {
      depois = await getDoc(doc(ctx.firestore(), "users", UID));
    });
    assert.strictEqual(depois.get("codigoSocio"), "A2B3C4");
    assert.strictEqual(depois.get("stripeCustomerId"), "cus_123");
    assert.strictEqual(depois.get("nome"), "Novo nome");
  });
});

// ---------------------------------------------------------------------------
// users — o que a lista branca precisa barrar
// ---------------------------------------------------------------------------

describe("users: escritas que precisam ser barradas", () => {
  test("sócio não pode se promover a admin", async () => {
    await semRegras((db) => setDoc(doc(db, "users", UID), { uid: UID }));
    await assertFails(updateDoc(doc(eu(), "users", UID), { role: "admin" }));
  });

  test("sócio não pode forjar stripeCustomerId (checkout na conta alheia)", async () => {
    await semRegras((db) => setDoc(doc(db, "users", UID), { uid: UID }));
    await assertFails(
      updateDoc(doc(eu(), "users", UID), { stripeCustomerId: "cus_da_vitima" })
    );
  });

  test("sócio não pode forjar codigoSocio (identidade no PDV)", async () => {
    await semRegras((db) => setDoc(doc(db, "users", UID), { uid: UID }));
    await assertFails(
      updateDoc(doc(eu(), "users", UID), { codigoSocio: "VITIMA" })
    );
  });

  test("sócio não pode inflar o contador de indicações", async () => {
    await semRegras((db) => setDoc(doc(db, "users", UID), { uid: UID }));
    await assertFails(updateDoc(doc(eu(), "users", UID), { indicacoes: 9999 }));
  });

  test("sócio não lê nem escreve o perfil de outro", async () => {
    await semRegras((db) => setDoc(doc(db, "users", OUTRO), { uid: OUTRO }));
    await assertFails(getDoc(doc(eu(), "users", OUTRO)));
    await assertFails(updateDoc(doc(eu(), "users", OUTRO), { nome: "invadido" }));
  });

  test("admin lê o perfil de qualquer sócio", async () => {
    await semRegras((db) => setDoc(doc(db, "users", OUTRO), { uid: OUTRO }));
    await assertSucceeds(getDoc(doc(admin(), "users", OUTRO)));
  });
});

// ---------------------------------------------------------------------------
// Demais coleções
// ---------------------------------------------------------------------------

describe("outras coleções", () => {
  test("config/app é público — o VersionGate lê antes do login", async () => {
    await semRegras((db) => setDoc(doc(db, "config", "app"), { minBuild: 3 }));
    await assertSucceeds(getDoc(doc(anonimo(), "config", "app")));
    await assertFails(setDoc(doc(anonimo(), "config", "app"), { minBuild: 0 }));
  });

  test("vitrine (plans/promotions/rewards/menu/funcionarios) exige sessão", async () => {
    for (const col of ["plans", "promotions", "rewards", "menu", "funcionarios"]) {
      await semRegras((db) => setDoc(doc(db, col, "x"), { a: 1 }));
      await assertFails(getDoc(doc(anonimo(), col, "x")));
      await assertSucceeds(getDoc(doc(eu(), col, "x")));
      await assertFails(setDoc(doc(eu(), col, "x"), { a: 2 }));
    }
  });

  test("payments e redemptions: cada um vê só o que é seu", async () => {
    await semRegras(async (db) => {
      await setDoc(doc(db, "payments", "p1"), { userId: UID, valor: 10 });
      await setDoc(doc(db, "payments", "p2"), { userId: OUTRO, valor: 10 });
      await setDoc(doc(db, "redemptions", "r1"), { userId: UID });
      await setDoc(doc(db, "redemptions", "r2"), { userId: OUTRO });
    });
    await assertSucceeds(getDoc(doc(eu(), "payments", "p1")));
    await assertFails(getDoc(doc(eu(), "payments", "p2")));
    await assertSucceeds(getDoc(doc(eu(), "redemptions", "r1")));
    await assertFails(getDoc(doc(eu(), "redemptions", "r2")));
    // Nem o dono escreve: resgate e cobrança só saem de Cloud Function.
    await assertFails(updateDoc(doc(eu(), "redemptions", "r1"), { status: "usado" }));
    await assertFails(updateDoc(doc(eu(), "payments", "p1"), { valor: 0 }));
  });

  test("central de avisos: dono marca como lida, mas não cria nem apaga", async () => {
    await semRegras((db) =>
      setDoc(doc(db, "users", UID, "notifications", "n1"), {
        titulo: "Oi",
        lida: false,
      })
    );
    await assertSucceeds(
      updateDoc(doc(eu(), "users", UID, "notifications", "n1"), { lida: true })
    );
    await assertFails(
      setDoc(doc(eu(), "users", UID, "notifications", "n2"), { titulo: "falso" })
    );
  });

  test("índices reversos de código são invisíveis ao cliente", async () => {
    await semRegras(async (db) => {
      await setDoc(doc(db, "socioCodes", "A2B3C4"), { uid: UID });
      await setDoc(doc(db, "referralCodes", "XYZ123"), { uid: UID });
    });
    await assertFails(getDoc(doc(eu(), "socioCodes", "A2B3C4")));
    await assertFails(getDoc(doc(admin(), "socioCodes", "A2B3C4")));
    await assertFails(getDoc(doc(eu(), "referralCodes", "XYZ123")));
  });

  test("cupons de um prêmio são invisíveis ao cliente e ao admin", async () => {
    // O estoque virou um documento por unidade (functions/src/lib/cupons.ts).
    // Quem reserva é a Cloud Function; abrir a subcoleção entregaria a lista de
    // quem resgatou o quê, que é dado de outro sócio.
    await semRegras(async (db) => {
      await setDoc(doc(db, "rewards", "rw1"), { titulo: "Rodízio", estoque: 5 });
      await setDoc(doc(db, "rewards", "rw1", "cupons", "c1"), {
        status: "usado",
        userId: OUTRO,
      });
    });
    // O prêmio em si continua legível — é a vitrine.
    await assertSucceeds(getDoc(doc(eu(), "rewards", "rw1")));
    await assertFails(getDoc(doc(eu(), "rewards", "rw1", "cupons", "c1")));
    await assertFails(getDoc(doc(admin(), "rewards", "rw1", "cupons", "c1")));
    await assertFails(
      setDoc(doc(eu(), "rewards", "rw1", "cupons", "c2"), { status: "livre" })
    );
  });

  test("controle de exclusão de conta é fechado até para o próprio uid", async () => {
    await semRegras((db) => setDoc(doc(db, "exclusoes", UID), { uid: UID, etapa: 3 }));
    await assertFails(getDoc(doc(eu(), "exclusoes", UID)));
    await assertFails(getDoc(doc(admin(), "exclusoes", UID)));
    await assertFails(setDoc(doc(eu(), "exclusoes", UID), { etapa: 7 }));
  });

  test("notificationLogs: só admin lê", async () => {
    await semRegras((db) => setDoc(doc(db, "notificationLogs", "l1"), { enviados: 5 }));
    await assertFails(getDoc(doc(eu(), "notificationLogs", "l1")));
    await assertSucceeds(getDoc(doc(admin(), "notificationLogs", "l1")));
  });

  test("coleção desconhecida cai no fallback que nega tudo", async () => {
    await assertFails(setDoc(doc(eu(), "coisa_nova", "x"), { a: 1 }));
    await assertFails(getDoc(doc(admin(), "coisa_nova", "x")));
  });
});
