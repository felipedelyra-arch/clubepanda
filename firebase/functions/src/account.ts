import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import { FieldValue, type Query } from "firebase-admin/firestore";
import { db, auth, storage } from "./lib/admin";
import { stripe } from "./lib/stripe";
import { requireAuth } from "./lib/guards";

/**
 * Exclusão de conta (LGPD + exigência das lojas).
 *
 * São sete etapas que mexem em quatro sistemas diferentes — Stripe, Firestore,
 * Storage e Auth — e não existe transação que as cubra. Antes elas rodavam em
 * sequência, sem marcar progresso: queda de rede, timeout ou erro do Stripe no
 * meio deixava a conta **meio apagada**, sem nada que retomasse. Assinatura
 * cancelada e perfil ainda de pé, ou perfil apagado e login ainda funcionando.
 *
 * Agora cada etapa concluída é gravada em `exclusoes/{uid}`. Chamar de novo
 * continua de onde parou, e [finalizarExclusoes] varre uma vez por dia o que
 * ficou pelo caminho — inclusive o caso em que a última etapa falha e o sócio
 * não tem mais como pedir de novo, porque a conta de login já não existe.
 */

/** Ordem das etapas. O número gravado é a última CONCLUÍDA. */
const ETAPAS = {
  GATEWAY: 1,
  ASSINATURAS: 2,
  RESGATES: 3,
  INDICES: 4,
  PERFIL: 5,
  ARQUIVOS: 6,
  LOGIN: 7,
} as const;

const FINAL = ETAPAS.LOGIN;

/** Apaga tudo que casa com a consulta, em voltas de 450. */
async function apagarEmLote(query: Query) {
  for (;;) {
    const snap = await query.limit(450).get();
    if (snap.empty) return;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    if (snap.size < 450) return;
  }
}

/**
 * Executa as etapas que faltam para [uid], a partir da última concluída.
 *
 * Cada etapa é idempotente por si: apagar o que já não existe não é erro. A
 * marcação evita repetir trabalho, não evita repetição danosa.
 *
 * Exportada para `loadtest/verificar-exclusao.js` poder exercitá-la contra os
 * emuladores sem passar pela camada de autenticação.
 */
export async function executarExclusao(uid: string): Promise<number> {
  const controle = db.doc(`exclusoes/${uid}`);
  const atual = (await controle.get()).get("etapa") as number | undefined;
  let feito = atual ?? 0;

  const concluir = async (etapa: number) => {
    feito = etapa;
    await controle.set(
      { uid, etapa, atualizadoEm: FieldValue.serverTimestamp() },
      { merge: true }
    );
  };

  // O perfil precisa ser lido ANTES de ser apagado: é dele que saem os códigos
  // dos índices reversos.
  const perfil = await db.doc(`users/${uid}`).get();

  if (feito < ETAPAS.GATEWAY) {
    const subs = await db.collection("subscriptions").where("userId", "==", uid).get();
    for (const s of subs.docs) {
      const gatewaySubId = s.get("gatewaySubscriptionId");
      if (!gatewaySubId) continue;
      try {
        await stripe().subscriptions.cancel(gatewaySubId);
      } catch {
        // Já cancelada ou inexistente no gateway — segue a exclusão.
      }
    }
    await concluir(ETAPAS.GATEWAY);
  }

  if (feito < ETAPAS.ASSINATURAS) {
    await apagarEmLote(db.collection("subscriptions").where("userId", "==", uid));
    await concluir(ETAPAS.ASSINATURAS);
  }

  if (feito < ETAPAS.RESGATES) {
    await apagarEmLote(db.collection("redemptions").where("userId", "==", uid));
    await concluir(ETAPAS.RESGATES);
  }

  if (feito < ETAPAS.INDICES) {
    // Índices reversos código -> uid. Deixados para trás, continuam resolvendo
    // para um uid que não existe mais: `acharUsuario` (lib/consumo.ts)
    // devolveria esse uid e o consumo do salão viraria conta de um dono que já
    // apagou a conta. E, para a LGPD, o índice guardaria um identificador
    // vinculável depois do "apague meus dados".
    const codigoSocio = perfil.get("codigoSocio") as string | undefined;
    const codigoIndicacao = perfil.get("codigoIndicacao") as string | undefined;
    if (codigoSocio) await db.doc(`socioCodes/${codigoSocio}`).delete();
    if (codigoIndicacao) await db.doc(`referralCodes/${codigoIndicacao}`).delete();
    await concluir(ETAPAS.INDICES);
  }

  if (feito < ETAPAS.PERFIL) {
    // Perfil + subcoleções (a central de avisos pode ter centenas de docs).
    await db.recursiveDelete(db.doc(`users/${uid}`));
    await concluir(ETAPAS.PERFIL);
  }

  if (feito < ETAPAS.ARQUIVOS) {
    try {
      await storage.bucket().deleteFiles({ prefix: `users/${uid}/` });
    } catch {
      // Sem arquivos para apagar, ou Storage ainda não habilitado no projeto.
    }
    await concluir(ETAPAS.ARQUIVOS);
  }

  if (feito < ETAPAS.LOGIN) {
    // Por último: invalida o token do cliente, e depois disto ele não tem mais
    // como chamar esta função. Por isso é a última.
    try {
      await auth.deleteUser(uid);
    } catch (err) {
      if ((err as { code?: string }).code !== "auth/user-not-found") throw err;
    }
    await concluir(ETAPAS.LOGIN);
  }

  return feito;
}

/** O sócio pede a exclusão da própria conta. */
export const deleteAccount = onCall(async (req) => {
  const uid = requireAuth(req);
  const etapa = await executarExclusao(uid);
  return { ok: true, etapa, completo: etapa >= FINAL };
});

/**
 * Termina as exclusões que pararam no meio.
 *
 * É a rede de segurança que o desenho anterior não tinha: sem ela, uma falha
 * na última etapa deixaria a conta sem dados mas com login ativo, e o sócio não
 * teria como pedir de novo — o app exige sessão, e a sessão é justamente o que
 * sobrou.
 */
export const finalizarExclusoes = onSchedule(
  { schedule: "every 24 hours", timeZone: "America/Sao_Paulo" },
  async () => {
    const pendentes = await db
      .collection("exclusoes")
      .where("etapa", "<", FINAL)
      .limit(200)
      .get();

    for (const doc of pendentes.docs) {
      try {
        const etapa = await executarExclusao(doc.id);
        logger.info("Exclusão retomada.", { uid: doc.id, etapa });
      } catch (err) {
        logger.error("Exclusão pendente falhou de novo.", { uid: doc.id, err });
      }
    }
  }
);
