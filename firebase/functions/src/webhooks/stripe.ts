import { onRequest } from "firebase-functions/v2/https";
import type Stripe from "stripe";
import { db } from "../lib/admin";
import { stripe } from "../lib/stripe";
import { FieldValue } from "firebase-admin/firestore";

/**
 * Webhook do Stripe. Valida assinatura, cria/atualiza subscription e registra
 * payment. NUNCA confia no cliente — só este endpoint muda estado de cobrança.
 * Precisa de rawBody (firebase-functions v2 expõe req.rawBody).
 */
export const stripeWebhook = onRequest(
  { cors: false, invoker: "public" },
  async (req, res) => {
    const secret = process.env.STRIPE_WEBHOOK_SECRET;
    const sig = req.headers["stripe-signature"];
    if (!secret || !sig) {
      res.status(400).send("Webhook secret/assinatura ausente.");
      return;
    }

    let event: Stripe.Event;
    try {
      event = stripe().webhooks.constructEvent(
        (req as unknown as { rawBody: Buffer }).rawBody,
        sig as string,
        secret
      );
    } catch (err) {
      res.status(400).send(`Assinatura inválida: ${(err as Error).message}`);
      return;
    }

    try {
      switch (event.type) {
        case "checkout.session.completed": {
          const s = event.data.object as Stripe.Checkout.Session;
          const uid = s.metadata?.firebaseUid;
          const planId = s.metadata?.planId;
          if (uid && s.subscription) {
            await db.doc(`subscriptions/${s.subscription as string}`).set(
              {
                userId: uid,
                planId: planId ?? null,
                status: "active",
                gatewayCustomerId: s.customer as string,
                gatewaySubscriptionId: s.subscription as string,
                formaPagamento: "cartao",
                inicioEm: FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
          }
          break;
        }
        case "invoice.paid": {
          const inv = event.data.object as Stripe.Invoice;
          const uid = inv.subscription_details?.metadata?.firebaseUid;
          if (uid) {
            await db.collection("payments").add({
              userId: uid,
              valor: (inv.amount_paid ?? 0) / 100,
              metodo: "cartao",
              status: "aprovado",
              gatewayRef: inv.id,
              data: FieldValue.serverTimestamp(),
            });
            if (inv.subscription) {
              await db.doc(`subscriptions/${inv.subscription as string}`).set(
                {
                  status: "active",
                  proximaCobranca: inv.lines.data[0]?.period?.end
                    ? new Date(inv.lines.data[0].period.end * 1000)
                    : null,
                },
                { merge: true }
              );
            }
          }
          break;
        }
        case "invoice.payment_failed": {
          const inv = event.data.object as Stripe.Invoice;
          if (inv.subscription) {
            await db
              .doc(`subscriptions/${inv.subscription as string}`)
              .set({ status: "past_due" }, { merge: true });
          }
          break;
        }
        case "customer.subscription.deleted": {
          const sub = event.data.object as Stripe.Subscription;
          await db
            .doc(`subscriptions/${sub.id}`)
            .set({ status: "canceled" }, { merge: true });
          break;
        }
        default:
          break;
      }
      res.status(200).send({ received: true });
    } catch (err) {
      console.error("Erro processando webhook Stripe:", err);
      res.status(500).send("Erro interno.");
    }
  }
);
