import { onCall, HttpsError } from "firebase-functions/v2/https";
import { randomUUID } from "crypto";
import { db } from "./lib/admin";
import { FieldValue } from "firebase-admin/firestore";
import { requireAuth, requireAdmin } from "./lib/guards";

/**
 * Resgata uma premiação. Transação atômica: valida pontos/estoque/assinante,
 * debita pontos, baixa estoque e cria redemption com código/QR único.
 */
export const redeemReward = onCall(async (req) => {
  const uid = requireAuth(req);
  const { rewardId } = req.data as { rewardId?: string };
  if (!rewardId) throw new HttpsError("invalid-argument", "rewardId obrigatório.");

  const codigo = randomUUID().replace(/-/g, "").slice(0, 12).toUpperCase();

  const redemptionId = await db.runTransaction(async (tx) => {
    const rewardRef = db.doc(`rewards/${rewardId}`);
    const userRef = db.doc(`users/${uid}`);
    const [rewardSnap, userSnap] = await Promise.all([
      tx.get(rewardRef),
      tx.get(userRef),
    ]);

    if (!rewardSnap.exists) throw new HttpsError("not-found", "Premiação não existe.");
    if (!userSnap.exists) throw new HttpsError("not-found", "Usuário não existe.");

    const reward = rewardSnap.data()!;
    const user = userSnap.data()!;

    const estoque = reward.estoque ?? 0;
    if (estoque <= 0) throw new HttpsError("failed-precondition", "Sem estoque.");

    // Exclusivo assinante?
    if (reward.apenasAssinantes === true) {
      const subs = await db
        .collection("subscriptions")
        .where("userId", "==", uid)
        .where("status", "==", "active")
        .limit(1)
        .get();
      if (subs.empty) {
        throw new HttpsError("permission-denied", "Exclusivo para assinantes.");
      }
    }

    const custo = reward.custoPontos ?? 0;
    const pontos = user.pontos ?? 0;
    if (pontos < custo) {
      throw new HttpsError("failed-precondition", "Pontos insuficientes.");
    }

    // Efeitos
    tx.update(rewardRef, { estoque: estoque - 1 });
    if (custo > 0) tx.update(userRef, { pontos: pontos - custo });

    const redemptionRef = db.collection("redemptions").doc();
    tx.set(redemptionRef, {
      userId: uid,
      rewardId,
      rewardTitulo: reward.titulo ?? "",
      codigo,
      status: "disponivel",
      criadoEm: FieldValue.serverTimestamp(),
    });
    return redemptionRef.id;
  });

  return { ok: true, redemptionId, codigo };
});

/** Admin valida um resgate (marca como usado). */
export const validateRedemption = onCall(async (req) => {
  requireAdmin(req);
  const { codigo } = req.data as { codigo?: string };
  if (!codigo) throw new HttpsError("invalid-argument", "codigo obrigatório.");

  const snap = await db
    .collection("redemptions")
    .where("codigo", "==", codigo)
    .limit(1)
    .get();
  if (snap.empty) throw new HttpsError("not-found", "Resgate não encontrado.");

  const doc = snap.docs[0];
  if (doc.get("status") !== "disponivel") {
    throw new HttpsError("failed-precondition", `Resgate já ${doc.get("status")}.`);
  }
  await doc.ref.update({ status: "usado", usadoEm: FieldValue.serverTimestamp() });
  return { ok: true, redemptionId: doc.id };
});
