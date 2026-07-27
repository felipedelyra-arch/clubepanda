import { onCall } from "firebase-functions/v2/https";
import type { Query } from "firebase-admin/firestore";
import { db, auth, storage } from "./lib/admin";
import { stripe } from "./lib/stripe";
import { requireAuth } from "./lib/guards";

/**
 * Exclui a conta do usuário e todos os seus dados (LGPD + exigência das lojas).
 * Ordem: cancela assinatura no gateway, apaga Firestore (perfil + subcoleção
 * notifications, resgates, assinaturas), remove avatar do Storage e, por fim,
 * deleta o usuário do Auth. Feito via Admin SDK, sem exigir re-login do cliente.
 */
export const deleteAccount = onCall(async (req) => {
  const uid = requireAuth(req);

  // 1. Cancela assinaturas no gateway (imediato).
  const subs = await db
    .collection("subscriptions")
    .where("userId", "==", uid)
    .get();
  for (const s of subs.docs) {
    const gatewaySubId = s.get("gatewaySubscriptionId");
    if (gatewaySubId) {
      try {
        await stripe().subscriptions.cancel(gatewaySubId);
      } catch {
        // Já cancelada/inexistente no gateway — segue a exclusão.
      }
    }
  }

  // 2. Apaga os documentos do usuário.
  const apagarEmLote = async (query: Query) => {
    const snap = await query.get();
    if (snap.empty) return;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  };
  await apagarEmLote(db.collection("subscriptions").where("userId", "==", uid));
  await apagarEmLote(db.collection("redemptions").where("userId", "==", uid));
  // Perfil + subcoleções (ex.: notifications).
  await db.recursiveDelete(db.doc(`users/${uid}`));

  // 3. Remove avatar(es) do Storage, se houver.
  try {
    await storage.bucket().deleteFiles({ prefix: `users/${uid}/` });
  } catch {
    // Sem arquivos pra apagar.
  }

  // 4. Deleta do Auth por último (invalida o token do cliente).
  await auth.deleteUser(uid);

  return { ok: true };
});
