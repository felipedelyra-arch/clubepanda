import { onCall } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db, messaging } from "./lib/admin";
import { requireAdmin } from "./lib/guards";

/** Coleta fcmTokens dos usuários, opcionalmente só assinantes ativos. */
async function collectTokens(onlySubscribers: boolean): Promise<string[]> {
  const tokens: string[] = [];

  if (onlySubscribers) {
    const subs = await db
      .collection("subscriptions")
      .where("status", "==", "active")
      .get();
    const uids = [...new Set(subs.docs.map((d) => d.get("userId")))];
    // Firestore 'in' aceita até 30 por query — pagina.
    for (let i = 0; i < uids.length; i += 30) {
      const batch = uids.slice(i, i + 30);
      if (batch.length === 0) continue;
      const users = await db
        .collection("users")
        .where("uid", "in", batch)
        .get();
      users.forEach((u) => {
        const t = u.get("fcmToken");
        if (t) tokens.push(t);
      });
    }
  } else {
    const users = await db.collection("users").get();
    users.forEach((u) => {
      const t = u.get("fcmToken");
      if (t) tokens.push(t);
    });
  }
  return [...new Set(tokens)];
}

/** Envia push para todos ou só assinantes. Só admin. */
export const sendPush = onCall(async (req) => {
  requireAdmin(req);
  const { titulo, corpo, onlySubscribers, imagem } = req.data as {
    titulo: string;
    corpo: string;
    onlySubscribers?: boolean;
    imagem?: string;
  };

  const tokens = await collectTokens(!!onlySubscribers);
  if (tokens.length === 0) return { ok: true, enviados: 0 };

  let enviados = 0;
  // sendEachForMulticast aceita até 500 tokens por chamada.
  for (let i = 0; i < tokens.length; i += 500) {
    const chunk = tokens.slice(i, i + 500);
    const res = await messaging.sendEachForMulticast({
      tokens: chunk,
      notification: { title: titulo, body: corpo, imageUrl: imagem },
      android: { priority: "high" },
    });
    enviados += res.successCount;
  }
  return { ok: true, enviados };
});

/** Ao publicar promoção ativa, dispara push automático. */
export const onPromotionCreated = onDocumentCreated(
  "promotions/{promoId}",
  async (event) => {
    const promo = event.data?.data();
    if (!promo || promo.ativa !== true) return;

    const tokens = await collectTokens(!!promo.apenasAssinantes);
    for (let i = 0; i < tokens.length; i += 500) {
      const chunk = tokens.slice(i, i + 500);
      if (chunk.length === 0) continue;
      await messaging.sendEachForMulticast({
        tokens: chunk,
        notification: {
          title: `🐼 ${promo.titulo ?? "Nova promoção!"}`,
          body: promo.descricao ?? "Confira no Clube Panda.",
          imageUrl: promo.imagem,
        },
      });
    }
  }
);
