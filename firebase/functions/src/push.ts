import { onCall } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { db, messaging } from "./lib/admin";
import { requireAdmin } from "./lib/guards";

type Publico = "todos" | "assinantes";
type Origem = "manual" | "promocao" | "premio";

interface Alvo {
  uid: string;
  token?: string;
}

/**
 * Quem deve receber o aviso. Devolve o uid mesmo de quem não tem token: sem
 * token não dá pra tocar o celular, mas o aviso ainda precisa entrar na central
 * do app pra pessoa achar quando abrir.
 */
async function coletarAlvos(onlySubscribers: boolean): Promise<Alvo[]> {
  const alvos = new Map<string, Alvo>();

  const somar = (uid: string, token?: unknown) => {
    if (!uid) return;
    alvos.set(uid, { uid, token: typeof token === "string" ? token : undefined });
  };

  if (onlySubscribers) {
    const subs = await db
      .collection("subscriptions")
      .where("status", "==", "active")
      .get();
    const uids = [...new Set(subs.docs.map((d) => d.get("userId") as string))].filter(Boolean);
    // Firestore 'in' aceita até 30 por query — pagina.
    for (let i = 0; i < uids.length; i += 30) {
      const lote = uids.slice(i, i + 30);
      if (lote.length === 0) continue;
      const users = await db.collection("users").where("uid", "in", lote).get();
      users.forEach((u) => somar(u.get("uid") ?? u.id, u.get("fcmToken")));
    }
  } else {
    const users = await db.collection("users").get();
    users.forEach((u) => somar(u.get("uid") ?? u.id, u.get("fcmToken")));
  }

  return [...alvos.values()];
}

/** Grava o aviso na central de cada pessoa, em lotes (limite de 500 por batch). */
async function gravarNaCentral(
  alvos: Alvo[],
  aviso: { titulo: string; corpo: string; tipo: string }
) {
  for (let i = 0; i < alvos.length; i += 450) {
    const lote = db.batch();
    alvos.slice(i, i + 450).forEach((a) => {
      const ref = db.collection("users").doc(a.uid).collection("notifications").doc();
      lote.set(ref, {
        titulo: aviso.titulo,
        corpo: aviso.corpo,
        tipo: aviso.tipo,
        lida: false,
        criadoEm: FieldValue.serverTimestamp(),
      });
    });
    await lote.commit();
  }
}

/**
 * Único caminho de saída de aviso do Clube. Faz as três coisas que precisam
 * andar juntas:
 *   1. toca o celular (FCM);
 *   2. guarda o aviso na central do app (`users/{uid}/notifications`) — sem
 *      isso a tela "Avisos" do app fica sempre vazia, que era o comportamento
 *      anterior: ninguém escrevia nessa subcoleção;
 *   3. registra o disparo em `notificationLogs`, que vira o histórico do painel.
 */
async function enviarAviso(opts: {
  titulo: string;
  corpo: string;
  publico: Publico;
  origem: Origem;
  tipo?: string;
  imagem?: string;
}): Promise<number> {
  const { titulo, corpo, publico, origem, tipo = "info", imagem } = opts;
  const alvos = await coletarAlvos(publico === "assinantes");

  let enviados = 0;
  const tokens = alvos.map((a) => a.token).filter((t): t is string => !!t);
  // sendEachForMulticast aceita até 500 tokens por chamada.
  for (let i = 0; i < tokens.length; i += 500) {
    const lote = tokens.slice(i, i + 500);
    const res = await messaging.sendEachForMulticast({
      tokens: lote,
      notification: { title: titulo, body: corpo, imageUrl: imagem },
      android: { priority: "high" },
    });
    enviados += res.successCount;
  }

  await gravarNaCentral(alvos, { titulo, corpo, tipo });

  await db.collection("notificationLogs").add({
    titulo,
    corpo,
    publico,
    origem,
    enviados,
    alcancados: alvos.length,
    criadoEm: FieldValue.serverTimestamp(),
  });

  return enviados;
}

/** Envia para todos ou só assinantes. Só admin. */
export const sendPush = onCall(async (req) => {
  requireAdmin(req);
  const { titulo, corpo, onlySubscribers, imagem } = req.data as {
    titulo: string;
    corpo: string;
    onlySubscribers?: boolean;
    imagem?: string;
  };

  if (!titulo?.trim() || !corpo?.trim()) {
    return { ok: false, enviados: 0, erro: "Título e mensagem são obrigatórios." };
  }

  const enviados = await enviarAviso({
    titulo: titulo.trim(),
    corpo: corpo.trim(),
    publico: onlySubscribers ? "assinantes" : "todos",
    origem: "manual",
    imagem,
  });

  return { ok: true, enviados };
});

// ---------------------------------------------------------------------------
// Promoções
// ---------------------------------------------------------------------------

const paraData = (v: unknown): Date | null => (v instanceof Timestamp ? v.toDate() : null);

/** A promoção está valendo neste instante? Mesma regra do app e do painel. */
function vigente(promo: FirebaseFirestore.DocumentData, agora = new Date()): boolean {
  if (promo.ativa !== true) return false;
  const inicio = paraData(promo.validadeInicio);
  const fim = paraData(promo.validadeFim);
  if (inicio && agora < inicio) return false;
  if (fim && agora > fim) return false;
  return true;
}

async function avisarPromocao(
  ref: FirebaseFirestore.DocumentReference,
  promo: FirebaseFirestore.DocumentData
) {
  await enviarAviso({
    titulo: `🐼 ${promo.titulo ?? "Nova promoção!"}`,
    corpo: promo.descricao ?? "Confira no Clube Panda.",
    publico: promo.apenasAssinantes ? "assinantes" : "todos",
    origem: "promocao",
    tipo: "promo",
    imagem: promo.imagem,
  });
  // Marca pra nunca avisar duas vezes sobre a mesma promoção.
  await ref.set({ avisoEnviadoEm: FieldValue.serverTimestamp() }, { merge: true });
}

/**
 * Promoção publicada e já valendo: avisa na hora.
 *
 * Promoção **agendada** não avisa aqui — antes avisava, e o cliente recebia
 * "Festival de sashimi!" hoje pra uma oferta que só entra semana que vem, abria
 * o app e não achava nada. Quem cuida dessas é a `publicarPromocoesAgendadas`
 * abaixo, quando a data chega.
 */
export const onPromotionCreated = onDocumentCreated(
  "promotions/{promoId}",
  async (event) => {
    const snap = event.data;
    const promo = snap?.data();
    if (!snap || !promo) return;
    if (!vigente(promo)) {
      logger.info("Promoção fora da janela na criação; aviso adiado.", { promoId: snap.id });
      return;
    }
    await avisarPromocao(snap.ref, promo);
  }
);

/**
 * A cada 15 minutos, avisa sobre as promoções agendadas que acabaram de entrar
 * no ar. `avisoEnviadoEm` garante um aviso só por promoção.
 *
 * A coleção é pequena (um restaurante tem punhado de ofertas), então o filtro é
 * em memória — evita índice composto e o problema de consultar campo ausente.
 */
export const publicarPromocoesAgendadas = onSchedule(
  { schedule: "every 15 minutes", timeZone: "America/Sao_Paulo" },
  async () => {
    const snap = await db.collection("promotions").where("ativa", "==", true).get();
    const pendentes = snap.docs.filter((d) => !d.get("avisoEnviadoEm") && vigente(d.data()));

    for (const d of pendentes) {
      await avisarPromocao(d.ref, d.data());
      logger.info("Promoção agendada entrou no ar e foi avisada.", { promoId: d.id });
    }
  }
);

// ---------------------------------------------------------------------------
// Prêmios
// ---------------------------------------------------------------------------

/**
 * Prêmio novo com estoque também vira aviso. Antes só promoção avisava, então o
 * dono cadastrava um rodízio grátis e ninguém ficava sabendo.
 */
export const onRewardCreated = onDocumentCreated("rewards/{rewardId}", async (event) => {
  const snap = event.data;
  const premio = snap?.data();
  if (!snap || !premio) return;

  if ((premio.estoque ?? 0) <= 0) return;
  const ate = paraData(premio.resgatavelAte);
  if (ate && ate < new Date()) return;

  await enviarAviso({
    titulo: `🎁 ${premio.titulo ?? "Prêmio novo no Clube"}`,
    corpo: premio.descricao ?? "Resgate pelo app e retire no salão.",
    // Prêmio é benefício de sócio: só quem paga a mensalidade resgata.
    publico: "assinantes",
    origem: "premio",
    tipo: "promo",
    imagem: premio.imagem,
  });
  await snap.ref.set({ avisoEnviadoEm: FieldValue.serverTimestamp() }, { merge: true });
});
