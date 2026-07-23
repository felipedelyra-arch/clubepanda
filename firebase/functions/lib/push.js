"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onPromotionCreated = exports.sendPush = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-functions/v2/firestore");
const admin_1 = require("./lib/admin");
const guards_1 = require("./lib/guards");
/** Coleta fcmTokens dos usuários, opcionalmente só assinantes ativos. */
async function collectTokens(onlySubscribers) {
    const tokens = [];
    if (onlySubscribers) {
        const subs = await admin_1.db
            .collection("subscriptions")
            .where("status", "==", "active")
            .get();
        const uids = [...new Set(subs.docs.map((d) => d.get("userId")))];
        // Firestore 'in' aceita até 30 por query — pagina.
        for (let i = 0; i < uids.length; i += 30) {
            const batch = uids.slice(i, i + 30);
            if (batch.length === 0)
                continue;
            const users = await admin_1.db
                .collection("users")
                .where("uid", "in", batch)
                .get();
            users.forEach((u) => {
                const t = u.get("fcmToken");
                if (t)
                    tokens.push(t);
            });
        }
    }
    else {
        const users = await admin_1.db.collection("users").get();
        users.forEach((u) => {
            const t = u.get("fcmToken");
            if (t)
                tokens.push(t);
        });
    }
    return [...new Set(tokens)];
}
/** Envia push para todos ou só assinantes. Só admin. */
exports.sendPush = (0, https_1.onCall)(async (req) => {
    (0, guards_1.requireAdmin)(req);
    const { titulo, corpo, onlySubscribers, imagem } = req.data;
    const tokens = await collectTokens(!!onlySubscribers);
    if (tokens.length === 0)
        return { ok: true, enviados: 0 };
    let enviados = 0;
    // sendEachForMulticast aceita até 500 tokens por chamada.
    for (let i = 0; i < tokens.length; i += 500) {
        const chunk = tokens.slice(i, i + 500);
        const res = await admin_1.messaging.sendEachForMulticast({
            tokens: chunk,
            notification: { title: titulo, body: corpo, imageUrl: imagem },
            android: { priority: "high" },
        });
        enviados += res.successCount;
    }
    return { ok: true, enviados };
});
/** Ao publicar promoção ativa, dispara push automático. */
exports.onPromotionCreated = (0, firestore_1.onDocumentCreated)("promotions/{promoId}", async (event) => {
    const promo = event.data?.data();
    if (!promo || promo.ativa !== true)
        return;
    const tokens = await collectTokens(!!promo.apenasAssinantes);
    for (let i = 0; i < tokens.length; i += 500) {
        const chunk = tokens.slice(i, i + 500);
        if (chunk.length === 0)
            continue;
        await admin_1.messaging.sendEachForMulticast({
            tokens: chunk,
            notification: {
                title: `🐼 ${promo.titulo ?? "Nova promoção!"}`,
                body: promo.descricao ?? "Confira no Clube Panda.",
                imageUrl: promo.imagem,
            },
        });
    }
});
//# sourceMappingURL=push.js.map