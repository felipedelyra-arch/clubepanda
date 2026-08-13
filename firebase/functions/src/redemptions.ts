import { onCall, HttpsError } from "firebase-functions/v2/https";
import { randomUUID } from "crypto";
import { db } from "./lib/admin";
import { FieldValue } from "firebase-admin/firestore";
import { requireAuth, requireAdmin } from "./lib/guards";

/**
 * Resgata uma premiação (benefício exclusivo de sócios). Transação atômica:
 * valida assinatura ativa, estoque, janela de resgate (resgatavelAte) e limite
 * de 1 por pessoa; baixa estoque e cria redemption com código/QR único.
 * Não há mais custo em pontos — o dono libera o prêmio com prazo.
 */
export const redeemReward = onCall(async (req) => {
  const uid = requireAuth(req);
  const { rewardId } = req.data as { rewardId?: string };
  if (!rewardId) throw new HttpsError("invalid-argument", "rewardId obrigatório.");

  // Só sócios resgatam. Leitura fora da transação (não afeta consistência do estoque).
  const subs = await db
    .collection("subscriptions")
    .where("userId", "==", uid)
    .where("status", "==", "active")
    .limit(1)
    .get();
  if (subs.empty) {
    throw new HttpsError("permission-denied", "Premiações são exclusivas para sócios.");
  }

  const codigo = randomUUID().replace(/-/g, "").slice(0, 12).toUpperCase();

  const redemptionId = await db.runTransaction(async (tx) => {
    const rewardRef = db.doc(`rewards/${rewardId}`);
    // 1 por pessoa: já existe resgate deste prêmio pra este usuário?
    const jaResgatouQuery = db
      .collection("redemptions")
      .where("userId", "==", uid)
      .where("rewardId", "==", rewardId)
      .limit(1);

    const [rewardSnap, jaResgatouSnap] = await Promise.all([
      tx.get(rewardRef),
      tx.get(jaResgatouQuery),
    ]);

    if (!rewardSnap.exists) throw new HttpsError("not-found", "Premiação não existe.");
    if (!jaResgatouSnap.empty) {
      throw new HttpsError("already-exists", "Você já resgatou este prêmio.");
    }

    const reward = rewardSnap.data()!;

    const estoque = reward.estoque ?? 0;
    if (estoque <= 0) throw new HttpsError("failed-precondition", "Sem estoque.");

    // Janela de resgate definida pelo dono.
    const resgatavelAte = reward.resgatavelAte as
      | FirebaseFirestore.Timestamp
      | undefined
      | null;
    if (resgatavelAte && resgatavelAte.toMillis() < Date.now()) {
      throw new HttpsError("failed-precondition", "Prazo de resgate encerrado.");
    }

    // Efeitos
    tx.update(rewardRef, { estoque: estoque - 1 });

    const redemptionRef = db.collection("redemptions").doc();
    tx.set(redemptionRef, {
      userId: uid,
      rewardId,
      rewardTitulo: reward.titulo ?? "",
      // Congela o valor do prêmio no momento do resgate. Sem isso, o
      // "você já economizou" do app seguiria o preço atual do prêmio — mudar
      // o cardápio reescreveria o passado do sócio.
      valor: Number(reward.valor ?? 0),
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
