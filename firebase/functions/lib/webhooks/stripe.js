"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.stripeWebhook = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin_1 = require("../lib/admin");
const stripe_1 = require("../lib/stripe");
const firestore_1 = require("firebase-admin/firestore");
/**
 * Webhook do Stripe. Valida assinatura, cria/atualiza subscription e registra
 * payment. NUNCA confia no cliente — só este endpoint muda estado de cobrança.
 * Precisa de rawBody (firebase-functions v2 expõe req.rawBody).
 */
exports.stripeWebhook = (0, https_1.onRequest)({ cors: false, invoker: "public" }, async (req, res) => {
    const secret = process.env.STRIPE_WEBHOOK_SECRET;
    const sig = req.headers["stripe-signature"];
    if (!secret || !sig) {
        res.status(400).send("Webhook secret/assinatura ausente.");
        return;
    }
    let event;
    try {
        event = (0, stripe_1.stripe)().webhooks.constructEvent(req.rawBody, sig, secret);
    }
    catch (err) {
        res.status(400).send(`Assinatura inválida: ${err.message}`);
        return;
    }
    try {
        switch (event.type) {
            case "checkout.session.completed": {
                const s = event.data.object;
                const uid = s.metadata?.firebaseUid;
                const planId = s.metadata?.planId;
                if (uid && s.subscription) {
                    await admin_1.db.doc(`subscriptions/${s.subscription}`).set({
                        userId: uid,
                        planId: planId ?? null,
                        status: "active",
                        gatewayCustomerId: s.customer,
                        gatewaySubscriptionId: s.subscription,
                        formaPagamento: "cartao",
                        inicioEm: firestore_1.FieldValue.serverTimestamp(),
                    }, { merge: true });
                }
                break;
            }
            case "invoice.paid": {
                const inv = event.data.object;
                const uid = inv.subscription_details?.metadata?.firebaseUid;
                if (uid) {
                    await admin_1.db.collection("payments").add({
                        userId: uid,
                        valor: (inv.amount_paid ?? 0) / 100,
                        metodo: "cartao",
                        status: "aprovado",
                        gatewayRef: inv.id,
                        data: firestore_1.FieldValue.serverTimestamp(),
                    });
                    if (inv.subscription) {
                        await admin_1.db.doc(`subscriptions/${inv.subscription}`).set({
                            status: "active",
                            proximaCobranca: inv.lines.data[0]?.period?.end
                                ? new Date(inv.lines.data[0].period.end * 1000)
                                : null,
                        }, { merge: true });
                    }
                }
                break;
            }
            case "invoice.payment_failed": {
                const inv = event.data.object;
                if (inv.subscription) {
                    await admin_1.db
                        .doc(`subscriptions/${inv.subscription}`)
                        .set({ status: "past_due" }, { merge: true });
                }
                break;
            }
            case "customer.subscription.deleted": {
                const sub = event.data.object;
                await admin_1.db
                    .doc(`subscriptions/${sub.id}`)
                    .set({ status: "canceled" }, { merge: true });
                break;
            }
            default:
                break;
        }
        res.status(200).send({ received: true });
    }
    catch (err) {
        console.error("Erro processando webhook Stripe:", err);
        res.status(500).send("Erro interno.");
    }
});
//# sourceMappingURL=stripe.js.map