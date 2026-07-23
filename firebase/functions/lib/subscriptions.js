"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cancelSubscription = exports.createCheckoutSession = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin_1 = require("./lib/admin");
const stripe_1 = require("./lib/stripe");
const guards_1 = require("./lib/guards");
/**
 * Cria uma sessão de checkout Stripe para assinatura recorrente.
 * Retorna a URL do checkout. A confirmação real vem via webhook.
 */
exports.createCheckoutSession = (0, https_1.onCall)(async (req) => {
    const uid = (0, guards_1.requireAuth)(req);
    const { planId, successUrl, cancelUrl } = req.data;
    if (!planId)
        throw new https_1.HttpsError("invalid-argument", "planId obrigatório.");
    const planSnap = await admin_1.db.doc(`plans/${planId}`).get();
    if (!planSnap.exists)
        throw new https_1.HttpsError("not-found", "Plano não existe.");
    const plan = planSnap.data();
    if (!plan.stripePriceId) {
        throw new https_1.HttpsError("failed-precondition", "Plano sem stripePriceId sincronizado.");
    }
    const user = await admin_1.auth.getUser(uid);
    // Reusa/cria customer do Stripe.
    const userDoc = await admin_1.db.doc(`users/${uid}`).get();
    let customerId = userDoc.get("stripeCustomerId");
    if (!customerId) {
        const customer = await (0, stripe_1.stripe)().customers.create({
            email: user.email ?? undefined,
            metadata: { firebaseUid: uid },
        });
        customerId = customer.id;
        await admin_1.db.doc(`users/${uid}`).set({ stripeCustomerId: customerId }, { merge: true });
    }
    const session = await (0, stripe_1.stripe)().checkout.sessions.create({
        mode: "subscription",
        customer: customerId,
        line_items: [{ price: plan.stripePriceId, quantity: 1 }],
        success_url: successUrl ?? "https://clube-panda.web.app/sucesso",
        cancel_url: cancelUrl ?? "https://clube-panda.web.app/planos",
        metadata: { firebaseUid: uid, planId },
        subscription_data: { metadata: { firebaseUid: uid, planId } },
    });
    return { ok: true, url: session.url, sessionId: session.id };
});
/** Cancela a assinatura ativa do usuário (ao fim do período). */
exports.cancelSubscription = (0, https_1.onCall)(async (req) => {
    const uid = (0, guards_1.requireAuth)(req);
    const subs = await admin_1.db
        .collection("subscriptions")
        .where("userId", "==", uid)
        .where("status", "==", "active")
        .limit(1)
        .get();
    if (subs.empty)
        throw new https_1.HttpsError("not-found", "Sem assinatura ativa.");
    const sub = subs.docs[0];
    const gatewaySubId = sub.get("gatewaySubscriptionId");
    if (gatewaySubId) {
        await (0, stripe_1.stripe)().subscriptions.update(gatewaySubId, { cancel_at_period_end: true });
    }
    await sub.ref.update({ status: "canceled" });
    return { ok: true };
});
//# sourceMappingURL=subscriptions.js.map