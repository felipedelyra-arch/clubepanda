/**
 * Cria o PRIMEIRO admin (bootstrap). Rode uma vez local.
 *
 *   1. Baixe a service account key do Firebase Console
 *      (Configurações > Contas de serviço > Gerar nova chave).
 *   2. Salve como firebase/serviceAccountKey.json (já no .gitignore).
 *   3. node scripts/set-first-admin.js <uid-do-usuario>
 *
 * Depois disso, use o painel admin (função setAdminRole) para os demais.
 */
const admin = require("firebase-admin");
const serviceAccount = require("../serviceAccountKey.json");

const uid = process.argv[2];
if (!uid) {
  console.error("Uso: node scripts/set-first-admin.js <uid>");
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

admin
  .auth()
  .setCustomUserClaims(uid, { role: "admin" })
  .then(() =>
    admin.firestore().doc(`users/${uid}`).set({ role: "admin" }, { merge: true })
  )
  .then(() => {
    console.log(`✅ ${uid} agora é admin. Peça pra ele deslogar/logar de novo.`);
    process.exit(0);
  })
  .catch((err) => {
    console.error("Erro:", err);
    process.exit(1);
  });
