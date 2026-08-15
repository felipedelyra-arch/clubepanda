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
      // Sem txid não há como distinguir uma cobrança nova de um reenvio da
      // mesma, e todo gateway reenvia quando não recebe 2xx a tempo. Recusar
      // é melhor que gravar duplicado: o 400 aparece no log de quem chamou.
      if (!body.txid) {
        res.status(400).send("txid obrigatório.");
        return;
      }

      // Id derivado do txid, e `create` em vez de `add`: o reenvio da mesma
      // cobrança bate em ALREADY_EXISTS em vez de virar uma segunda linha no
      // financeiro do dono. Mesmo tratamento que o webhook do Stripe já tinha.
      try {
        await db.doc(`payments/pix_${body.txid}`).create({
          userId: body.firebaseUid,
          valor: body.valor ?? 0,
          metodo: "pix",
          status: "aprovado",
          gatewayRef: body.txid,
          data: FieldValue.serverTimestamp(),
        });
      } catch (err) {
        if ((err as { code?: number }).code !== 6) throw err;
      }

      // Pix aqui trata pagamento avulso/assinatura conforme seu modelo.
      if (body.planId) {
        // Id derivado de quem assinou + o que assinou, não do txid: a
        // renovação chega com txid novo, e com `add()` cada mês virava mais
        // uma assinatura `active` para o mesmo sócio. Todo mundo que consulta
        // isso filtra por `userId` + `status` com `limit(1)` (redemptions.ts,
        // lib/consumo.ts, push.ts), então o duplicado não dava erro em lugar
        // nenhum — só inflava relatório e deixava resíduo no cancelamento.
        const subRef = db.doc(`subscriptions/pix_${body.firebaseUid}_${body.planId}`);
        const jaExiste = (await subRef.get()).exists;
        await subRef.set(
          {
            userId: body.firebaseUid,
            planId: body.planId,
            status: "active",
            gatewaySubscriptionId: body.txid,
            formaPagamento: "pix",
            // Só na criação: renovação não pode reescrever a data de início.
            ...(jaExiste ? {} : { inicioEm: FieldValue.serverTimestamp() }),
          },
          { merge: true }
        );
      }
    }

    res.status(200).send({ received: true });
  } catch (err) {
    console.error("Erro webhook Pix:", err);
    res.status(500).send("Erro interno.");
  }
});
