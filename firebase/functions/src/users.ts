import { beforeUserCreated } from "firebase-functions/v2/identity";
import { onCall } from "firebase-functions/v2/https";
import { db } from "./lib/admin";
import { FieldValue } from "firebase-admin/firestore";
import { garantirCodigoSocio } from "./lib/codigoSocio";
import { requireAdmin } from "./lib/guards";

/**
 * Ao criar conta (Auth), garante o doc de perfil em users/.
 * Escrita pelo backend => ignora rules, mas mantém consistência.
 */
export const onAuthUserCreate = beforeUserCreated(async (event) => {
  const user = event.data;
  if (!user) return;

  const ref = db.doc(`users/${user.uid}`);
  const snap = await ref.get();
  if (!snap.exists) {
    await ref.set({
      uid: user.uid,
      nome: user.displayName ?? "",
      email: user.email ?? "",
      telefone: user.phoneNumber ?? "",
      endereco: null,
      fcmToken: null,
      role: null,
      criadoEm: FieldValue.serverTimestamp(),
    });
  }

  // Depois do set (que é sem merge e apagaria o campo). A carteirinha lê isso
  // direto do doc, então já nasce pronta — sem chamada extra do app.
  // Falha aqui não pode barrar o cadastro: o backfill recupera depois.
  try {
    await garantirCodigoSocio(user.uid);
  } catch (err) {
    console.error(`Falha ao gerar codigoSocio de ${user.uid}:`, err);
  }
  return;
});

/**
 * Gera o código de sócio de quem foi criado antes desta funcionalidade existir.
 * Roda sob demanda pelo painel; é seguro chamar quantas vezes quiser, porque
 * quem já tem código é pulado.
 */
export const backfillCodigosSocio = onCall(async (req) => {
  requireAdmin(req);

  const snap = await db.collection("users").get();
  const pendentes = snap.docs.filter((d) => !d.get("codigoSocio"));

  let gerados = 0;
  const falhas: string[] = [];
  for (const doc of pendentes) {
    try {
      await garantirCodigoSocio(doc.id);
      gerados++;
    } catch (err) {
      console.error(`Backfill falhou em ${doc.id}:`, err);
      falhas.push(doc.id);
    }
  }

  return { total: snap.size, gerados, falhas };
});
