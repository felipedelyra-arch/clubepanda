import { beforeUserCreated } from "firebase-functions/v2/identity";
import { onCall } from "firebase-functions/v2/https";
import { db } from "./lib/admin";
import { FieldValue, FieldPath } from "firebase-admin/firestore";
import { garantirCodigoSocio } from "./lib/codigoSocio";
import { requireAdmin } from "./lib/guards";

/**
 * Ao criar conta (Auth), garante o doc de perfil em users/.
 * Escrita pelo backend => ignora rules, mas mantém consistência.
 */
export const onAuthUserCreate = beforeUserCreated(async (event) => {
  const user = event.data;
  if (!user) return;

  const ref = db.doc(`users/${user.uid}`);
  const snap = await ref.get();
  if (!snap.exists) {
    await ref.set({
      uid: user.uid,
      nome: user.displayName ?? "",
      email: user.email ?? "",
      telefone: user.phoneNumber ?? "",
      endereco: null,
      fcmToken: null,
      role: null,
      criadoEm: FieldValue.serverTimestamp(),
    });
  }

  // Depois do set (que é sem merge e apagaria o campo). A carteirinha lê isso
  // direto do doc, então já nasce pronta — sem chamada extra do app.
  // Falha aqui não pode barrar o cadastro: o backfill recupera depois.
  try {
    await garantirCodigoSocio(user.uid);
  } catch (err) {
    console.error(`Falha ao gerar codigoSocio de ${user.uid}:`, err);
  }
  return;
});

/** Quantos perfis são varridos por chamada. */
const BACKFILL_VARREDURA = 2000;
/** Quantos códigos são gerados por chamada (cada um é uma transação). */
const BACKFILL_GERADOS = 250;
/** Transações simultâneas. Documentos distintos, então não disputam nada. */
const BACKFILL_PARALELO = 10;

/**
 * Gera o código de sócio de quem foi criado antes desta funcionalidade existir.
 * Roda sob demanda pelo painel; é seguro chamar quantas vezes quiser, porque
 * quem já tem código é pulado.
 *
 * ⚠️ Processa um PEDAÇO por chamada e devolve `continua` + `cursor`. Antes
 * varria `users` inteiro e rodava uma transação por pessoa, uma esperando a
 * outra: com alguns milhares de pendentes isso passava dos 60s de timeout, a
 * função morria no meio e o painel só via um erro genérico — sem saber quantos
 * códigos tinham sido gravados antes de cair.
 *
 * Quem chama repete enquanto `continua` for true, passando o `cursor` de volta.
 */
export const backfillCodigosSocio = onCall(async (req) => {
  requireAdmin(req);
  const { cursor } = (req.data ?? {}) as { cursor?: string };

  // `codigoSocio` está AUSENTE em quem não tem (não é null), e o Firestore não
  // consulta campo ausente. Por isso a varredura é por id, paginada — o id é o
  // único campo que todo documento tem.
  let q = db
    .collection("users")
    .orderBy(FieldPath.documentId())
    .select("codigoSocio")
    .limit(BACKFILL_VARREDURA);
  if (cursor) q = q.startAfter(cursor);

  const snap = await q.get();
  const pendentes = snap.docs.filter((d) => !d.get("codigoSocio"));
  const lote = pendentes.slice(0, BACKFILL_GERADOS);

  let gerados = 0;
  const falhas: string[] = [];
  for (let i = 0; i < lote.length; i += BACKFILL_PARALELO) {
    await Promise.all(
      lote.slice(i, i + BACKFILL_PARALELO).map(async (doc) => {
        try {
          await garantirCodigoSocio(doc.id);
          gerados++;
        } catch (err) {
          console.error(`Backfill falhou em ${doc.id}:`, err);
          falhas.push(doc.id);
        }
      })
    );
  }

  // Se o corte por BACKFILL_GERADOS sobrou gente, o próximo pedaço recomeça no
  // último realmente processado — e não no fim da varredura, que pularia os
  // pendentes que ficaram de fora.
  const ultimo = lote.length < pendentes.length
    ? lote[lote.length - 1]?.id
    : snap.docs[snap.docs.length - 1]?.id;

  const continua = snap.size === BACKFILL_VARREDURA || lote.length < pendentes.length;

  return {
    varridos: snap.size,
    gerados,
    falhas,
    continua,
    cursor: continua ? ultimo : null,
  };
});
