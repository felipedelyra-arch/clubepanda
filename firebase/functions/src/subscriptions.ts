import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, auth } from "./lib/admin";
import { stripe } from "./lib/stripe";
import { requireAuth } from "./lib/guards";

/**
 * Cria uma sessão de checkout Stripe para assinatura recorrente.
 * Retorna a URL do checkout. A confirmação real vem via webhook.
 */
export const createCheckoutSession = onCall(async (req) => {
  const uid = requireAuth(req);
  const { planId, successUrl, cancelUrl } = req.data as {
    planId?: string;
    successUrl?: string;
    cancelUrl?: string;
  };
  if (!planId) throw new HttpsError("invalid-argument", "planId obrigatório.");

  const planSnap = await db.doc(`plans/${planId}`).get();
  if (!planSnap.exists) throw new HttpsError("not-found", "Plano não existe.");
  const plan = planSnap.data()!;
  if (!plan.stripePriceId) {
    throw new HttpsError("failed-precondition", "Plano sem stripePriceId sincronizado.");
  }

  const user = await auth.getUser(uid);

  // Reusa/cria customer do Stripe.
  const userDoc = await db.doc(`users/${uid}`).get();
  let customerId: string | undefined = userDoc.get("stripeCustomerId");
  if (!customerId) {
    const customer = await stripe().customers.create({
      email: user.email ?? undefined,
      metadata: { firebaseUid: uid },
    });
    customerId = customer.id;
    await db.doc(`users/${uid}`).set({ stripeCustomerId: customerId }, { merge: true });
  }

  const session = await stripe().checkout.sessions.create({
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
export const cancelSubscription = onCall(async (req) => {
  const uid = requireAuth(req);

  const subs = await db
    .collection("subscriptions")
    .where("userId", "==", uid)
    .where("status", "==", "active")
    .limit(1)
    .get();
  if (subs.empty) throw new HttpsError("not-found", "Sem assinatura ativa.");

  const sub = subs.docs[0];
  const gatewaySubId = sub.get("gatewaySubscriptionId");
  if (gatewaySubId) {
    await stripe().subscriptions.update(gatewaySubId, { cancel_at_period_end: true });
  }
  await sub.ref.update({ status: "canceled" });
  return { ok: true };
});
