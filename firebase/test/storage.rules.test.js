/**
 * Teste das Storage Security Rules contra o emulador.
 *
 * Existe porque `storage.rules` nunca tinha rodado em lugar nenhum: não é
 * publicado sem o Blaze, e nenhum teste o carregava. Ficou meses valendo só no
 * papel, e a auditoria de 15/08 achou nele uma leitura larga demais — foto de
 * perfil legível por qualquer sócio logado, bastando saber o uid do outro.
 *
 * A regressão desse achado é o caso "sócio não lê a foto de outro" aqui embaixo.
 *
 * Rodar:  cd firebase/functions && npm run test:storage
 *         (com `firebase emulators:start --only storage` no ar)
 */
const { test, before, after, beforeEach, describe } = require("node:test");
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
const { ref, uploadBytes, getBytes } = mod("firebase/storage");
const { setLogLevel } = mod("firebase/app");

const UID = "socio_teste";
const OUTRO = "outro_socio";

/** JPEG mínimo. O conteúdo não importa pras rules, o contentType importa. */
const IMAGEM = new Uint8Array([0xff, 0xd8, 0xff, 0xdb, 0x00, 0x43, 0x00]);
const JPEG = { contentType: "image/jpeg" };

let env;

before(async () => {
  setLogLevel("error"); // sem o ruído de "permission denied" esperado
  env = await initializeTestEnvironment({
    projectId: "pandavip-storage-test",
    storage: {
      host: "127.0.0.1",
      port: 9199,
      rules: fs.readFileSync(path.join(__dirname, "..", "storage.rules"), "utf8"),
    },
  });
});

after(async () => {
  if (env) await env.cleanup();
});

beforeEach(async () => {
  await env.clearStorage();
});

/** Cliente do próprio sócio. */
const eu = () => env.authenticatedContext(UID).storage();
/** Outro sócio, logado igual — é o vizinho de clube, não um invasor. */
const outro = () => env.authenticatedContext(OUTRO).storage();
/** Cliente admin (custom claim role=admin). */
const admin = () => env.authenticatedContext("chefe", { role: "admin" }).storage();
/** Cliente deslogado. */
const anonimo = () => env.unauthenticatedContext().storage();

/** Põe um arquivo no bucket ignorando as rules (é o que o backend faria). */
async function semRegras(caminho) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), caminho), IMAGEM, JPEG);
  });
}

// ---------------------------------------------------------------------------
// users/{uid} — foto de perfil
// ---------------------------------------------------------------------------

describe("foto de perfil", () => {
  test("profile_screen.dart:237 — o dono envia a própria foto", async () => {
    await assertSucceeds(
      uploadBytes(ref(eu(), `users/${UID}/avatar_1.jpg`), IMAGEM, JPEG)
    );
  });

  test("o dono lê a própria foto", async () => {
    await semRegras(`users/${UID}/avatar_1.jpg`);
    await assertSucceeds(getBytes(ref(eu(), `users/${UID}/avatar_1.jpg`)));
  });

  test("sócio NÃO lê a foto de outro sócio", async () => {
    await semRegras(`users/${OUTRO}/avatar_1.jpg`);
    await assertFails(getBytes(ref(eu(), `users/${OUTRO}/avatar_1.jpg`)));
  });

  test("admin lê a foto de qualquer sócio", async () => {
    await semRegras(`users/${UID}/avatar_1.jpg`);
    await assertSucceeds(getBytes(ref(admin(), `users/${UID}/avatar_1.jpg`)));
  });

  test("sócio não envia foto para a pasta de outro", async () => {
    await assertFails(
      uploadBytes(ref(eu(), `users/${OUTRO}/avatar_1.jpg`), IMAGEM, JPEG)
    );
  });

  test("deslogado não lê foto de perfil", async () => {
    await semRegras(`users/${UID}/avatar_1.jpg`);
    await assertFails(getBytes(ref(anonimo(), `users/${UID}/avatar_1.jpg`)));
  });

  test("arquivo que não é imagem é barrado", async () => {
    await assertFails(
      uploadBytes(ref(eu(), `users/${UID}/payload.pdf`), IMAGEM, {
        contentType: "application/pdf",
      })
    );
  });
});

// ---------------------------------------------------------------------------
// vitrine — promotions / rewards / menu
// ---------------------------------------------------------------------------

describe("imagens da vitrine", () => {
  test("são públicas: deslogado lê promoção, prêmio e prato", async () => {
    for (const pasta of ["promotions", "rewards", "menu"]) {
      await semRegras(`${pasta}/foto.jpg`);
      await assertSucceeds(getBytes(ref(anonimo(), `${pasta}/foto.jpg`)));
    }
  });

  test("só admin envia — sócio comum é barrado nas três pastas", async () => {
    for (const pasta of ["promotions", "rewards", "menu"]) {
      await assertFails(
        uploadBytes(ref(eu(), `${pasta}/foto.jpg`), IMAGEM, JPEG)
      );
    }
  });

  test("admin envia nas três pastas", async () => {
    for (const pasta of ["promotions", "rewards", "menu"]) {
      await assertSucceeds(
        uploadBytes(ref(admin(), `${pasta}/foto.jpg`), IMAGEM, JPEG)
      );
    }
  });
});

// ---------------------------------------------------------------------------
// fallback
// ---------------------------------------------------------------------------

describe("fallback", () => {
  test("caminho desconhecido nega leitura e escrita, até para o admin", async () => {
    await semRegras("qualquer/coisa.jpg");
    await assertFails(getBytes(ref(admin(), "qualquer/coisa.jpg")));
    await assertFails(
      uploadBytes(ref(admin(), "qualquer/coisa.jpg"), IMAGEM, JPEG)
    );
  });
});
