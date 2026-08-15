/**
 * Base dos medidores. Fala com o EMULADOR, nunca com produção.
 *
 * Por que Admin SDK e não k6: nesta stack não existe instância nossa pra
 * saturar. O que decide o teto é (a) quantas idas ao Firestore cada ação faz e
 * (b) quantas delas são sequenciais. Isso se mede contando e cronometrando as
 * operações — e o resultado vale pra produção porque o formato da curva é o
 * mesmo, mesmo que o tempo por operação seja diferente.
 */
// Reusa o SDK já instalado em firebase/functions — não é preciso um segundo
// node_modules só pros medidores.
const path = require("path");
const admin = require(
  path.join(__dirname, "..", "firebase", "functions", "node_modules", "firebase-admin")
);

const HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIRESTORE_EMULATOR_HOST = HOST;

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "pandavip" });
}

const db = admin.firestore();

/** Trava de segurança: se não estiver apontando pro emulador, aborta. */
function exigirEmulador() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    console.error("ABORTADO: FIRESTORE_EMULATOR_HOST não definido.");
    process.exit(1);
  }
}

/** Cronometra uma promessa e devolve [resultado, milissegundos]. */
async function cronometrar(fn) {
  const t0 = process.hrtime.bigint();
  const r = await fn();
  const ms = Number(process.hrtime.bigint() - t0) / 1e6;
  return [r, ms];
}

/** p50/p95/p99 de uma lista de números. */
function percentis(xs) {
  const s = [...xs].sort((a, b) => a - b);
  const at = (p) => s[Math.min(s.length - 1, Math.floor((p / 100) * s.length))];
  return { p50: at(50), p95: at(95), p99: at(99), max: s[s.length - 1] };
}

const ms = (n) => `${n.toFixed(0)}ms`;

module.exports = { admin, db, exigirEmulador, cronometrar, percentis, ms };
