"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateRedemption = exports.redeemReward = void 0;
const https_1 = require("firebase-functions/v2/https");
const crypto_1 = require("crypto");
const admin_1 = require("./lib/admin");
const firestore_1 = require("firebase-admin/firestore");
const guards_1 = require("./lib/guards");
/**
 * Resgata uma premiação. Transação atômica: valida pontos/estoque/assinante,
 * debita pontos, baixa estoque e cria redemption com código/QR único.
 */
exports.redeemReward = (0, https_1.onCall)(async (req) => {
    const uid = (0, guards_1.requireAuth)(req);
    const { rewardId } = req.data;
    if (!rewardId)
        throw new https_1.HttpsError("invalid-argument", "rewardId obrigatório.");
    const codigo = (0, crypto_1.randomUUID)().replace(/-/g, "").slice(0, 12).toUpperCase();
    const redemptionId = await admin_1.db.runTransaction(async (tx) => {
        const rewardRef = admin_1.db.doc(`rewards/${rewardId}`);
        const userRef = admin_1.db.doc(`users/${uid}`);
        const [rewardSnap, userSnap] = await Promise.all([
            tx.get(rewardRef),
            tx.get(userRef),
        ]);
        if (!rewardSnap.exists)
            throw new https_1.HttpsError("not-found", "Premiação não existe.");
        if (!userSnap.exists)
            throw new https_1.HttpsError("not-found", "Usuário não existe.");
        const reward = rewardSnap.data();
        const user = userSnap.data();
        const estoque = reward.estoque ?? 0;
        if (estoque <= 0)
            throw new https_1.HttpsError("failed-precondition", "Sem estoque.");
        // Exclusivo assinante?
        if (reward.apenasAssinantes === true) {
            const subs = await admin_1.db
                .collection("subscriptions")
                .where("userId", "==", uid)
                .where("status", "==", "active")
                .limit(1)
                .get();
            if (subs.empty) {
                throw new https_1.HttpsError("permission-denied", "Exclusivo para assinantes.");
            }
        }
        const custo = reward.custoPontos ?? 0;
        const pontos = user.pontos ?? 0;
        if (pontos < custo) {
            throw new https_1.HttpsError("failed-precondition", "Pontos insuficientes.");
        }
        // Efeitos
        tx.update(rewardRef, { estoque: estoque - 1 });
        if (custo > 0)
            tx.update(userRef, { pontos: pontos - custo });
        const redemptionRef = admin_1.db.collection("redemptions").doc();
        tx.set(redemptionRef, {
            userId: uid,
            rewardId,
            rewardTitulo: reward.titulo ?? "",
            codigo,
            status: "disponivel",
            criadoEm: firestore_1.FieldValue.serverTimestamp(),
        });
        return redemptionRef.id;
    });
    return { ok: true, redemptionId, codigo };
});
/** Admin valida um resgate (marca como usado). */
exports.validateRedemption = (0, https_1.onCall)(async (req) => {
    (0, guards_1.requireAdmin)(req);
    const { codigo } = req.data;
    if (!codigo)
        throw new https_1.HttpsError("invalid-argument", "codigo obrigatório.");
    const snap = await admin_1.db
        .collection("redemptions")
        .where("codigo", "==", codigo)
        .limit(1)
        .get();
    if (snap.empty)
        throw new https_1.HttpsError("not-found", "Resgate não encontrado.");
    const doc = snap.docs[0];
    if (doc.get("status") !== "disponivel") {
        throw new https_1.HttpsError("failed-precondition", `Resgate já ${doc.get("status")}.`);
    }
    await doc.ref.update({ status: "usado", usadoEm: firestore_1.FieldValue.serverTimestamp() });
    return { ok: true, redemptionId: doc.id };
});
//# sourceMappingURL=redemptions.js.map