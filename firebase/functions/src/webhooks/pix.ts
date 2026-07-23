import { onRequest } from "firebase-functions/v2/https";
import { createHmac, timingSafeEqual } from "crypto";
import { db } from "../lib/admin";
import { FieldValue } from "firebase-admin/firestore";

/**
 * Webhook genérico do gateway Pix. Adapte o parsing ao seu provedor
 * (Mercado Pago / Gerencianet / Asaas). Valida assinatura HMAC do header.
 */
export const pixWebhook = onRequest({ invoker: "public" }, async (req, res) => {
  const secret = process.env.PIX_WEBHOOK_SECRET;
  if (!secret) {
    res.status(500).send("PIX_WEBHOOK_SECRET não configurada.");
    return;
  }

  // Validação de assinatura (ajuste o header ao gateway real).
  const sig = req.headers["x-signature"] as string | undefined;
  const raw = (req as unknown as { rawBody: Buffer }).rawBody;
  const expected = createHmac("sha256", secret).update(raw).digest("hex");
  if (
    !sig ||
    sig.length !== expected.length ||
    !timingSafeEqual(Buffer.from(sig), Buffer.from(expected))
  ) {
    res.status(401).send("Assinatura inválida.");
    return;
  }

  try {
    // Formato depende do gateway. Exemplo genérico:
    const body = req.body as {
      event?: string;
      firebaseUid?: string;
      planId?: string;
      valor?: number;
      status?: string;
      txid?: string;
    };

    if (body.status === "paid" && body.firebaseUid) {
      await db.collection("payments").add({
        userId: body.firebaseUid,
        valor: body.valor ?? 0,
        metodo: "pix",
        status: "aprovado",
        gatewayRef: body.txid ?? null,
        data: FieldValue.serverTimestamp(),
      });

      // Pix aqui trata pagamento avulso/assinatura conforme seu modelo.
      if (body.planId) {
        await db.collection("subscriptions").add({
          userId: body.firebaseUid,
          planId: body.planId,
          status: "active",
          gatewaySubscriptionId: body.txid ?? null,
          formaPagamento: "pix",
          inicioEm: FieldValue.serverTimestamp(),
        });
      }
    }

    res.status(200).send({ received: true });
  } catch (err) {
    console.error("Erro webhook Pix:", err);
    res.status(500).send("Erro interno.");
  }
});
