"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.pixWebhook = void 0;
const https_1 = require("firebase-functions/v2/https");
const crypto_1 = require("crypto");
const admin_1 = require("../lib/admin");
const firestore_1 = require("firebase-admin/firestore");
/**
 * Webhook genérico do gateway Pix. Adapte o parsing ao seu provedor
 * (Mercado Pago / Gerencianet / Asaas). Valida assinatura HMAC do header.
 */
exports.pixWebhook = (0, https_1.onRequest)({ invoker: "public" }, async (req, res) => {
    const secret = process.env.PIX_WEBHOOK_SECRET;
    if (!secret) {
        res.status(500).send("PIX_WEBHOOK_SECRET não configurada.");
        return;
    }
    // Validação de assinatura (ajuste o header ao gateway real).
    const sig = req.headers["x-signature"];
    const raw = req.rawBody;
    const expected = (0, crypto_1.createHmac)("sha256", secret).update(raw).digest("hex");
    if (!sig ||
        sig.length !== expected.length ||
        !(0, crypto_1.timingSafeEqual)(Buffer.from(sig), Buffer.from(expected))) {
        res.status(401).send("Assinatura inválida.");
        return;
    }
    try {
        // Formato depende do gateway. Exemplo genérico:
        const body = req.body;
        if (body.status === "paid" && body.firebaseUid) {
            await admin_1.db.collection("payments").add({
                userId: body.firebaseUid,
                valor: body.valor ?? 0,
                metodo: "pix",
                status: "aprovado",
                gatewayRef: body.txid ?? null,
                data: firestore_1.FieldValue.serverTimestamp(),
            });
            // Pix aqui trata pagamento avulso/assinatura conforme seu modelo.
            if (body.planId) {
                await admin_1.db.collection("subscriptions").add({
                    userId: body.firebaseUid,
                    planId: body.planId,
                    status: "active",
                    gatewaySubscriptionId: body.txid ?? null,
                    formaPagamento: "pix",
                    inicioEm: firestore_1.FieldValue.serverTimestamp(),
                });
            }
        }
        res.status(200).send({ received: true });
    }
    catch (err) {
        console.error("Erro webhook Pix:", err);
        res.status(500).send("Erro interno.");
    }
});
//# sourceMappingURL=pix.js.map