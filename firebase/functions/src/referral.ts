import { onCall, HttpsError } from "firebase-functions/v2/https";
import { randomUUID } from "crypto";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "./lib/admin";
import { requireAuth } from "./lib/guards";

/**
 * Garante um código de indicação único pro usuário e o retorna (cria na 1ª vez).
 * Também devolve quantas indicações já rendeu.
 */
export const ensureReferralCode = onCall(async (req) => {
  const uid = requireAuth(req);
  const userRef = db.doc(`users/${uid}`);
  const snap = await userRef.get();

  const jaTem = snap.get("codigoIndicacao") as string | undefined;
  if (jaTem) {
    return { code: jaTem, indicacoes: (snap.get("indicacoes") as number) ?? 0 };
  }

  let code: string | null = null;
  for (let i = 0; i < 5 && !code; i++) {
    const cand = randomUUID().replace(/-/g, "").slice(0, 6).toUpperCase();
    const lookupRef = db.doc(`referralCodes/${cand}`);
    const ok = await db.runTransaction(async (tx) => {
      const existe = await tx.get(lookupRef);
      if (existe.exists) return false;
      tx.set(lookupRef, { uid, criadoEm: FieldValue.serverTimestamp() });
      tx.set(userRef, { codigoIndicacao: cand }, { merge: true });
      return true;
    });
    if (ok) code = cand;
  }
  if (!code) throw new HttpsError("internal", "Não deu pra gerar o código.");

  return { code, indicacoes: (snap.get("indicacoes") as number) ?? 0 };
});

/**
 * Registra que o usuário atual foi indicado por um código. Só uma vez por conta,
 * não pode indicar a si mesmo. Incrementa o contador de quem indicou.
 * A recompensa (benefício pros dois) é concedida na ativação da assinatura
 * — ver hook no webhook de pagamento.
 */
export const applyReferral = onCall(async (req) => {
  const uid = requireAuth(req);
  const { code } = req.data as { code?: string };
  if (!code) throw new HttpsError("invalid-argument", "code obrigatório.");
  const codeUp = code.trim().toUpperCase();

  const userRef = db.doc(`users/${uid}`);
  const meSnap = await userRef.get();
  if (meSnap.get("indicadoPor")) {
    throw new HttpsError("already-exists", "Você já usou um código de indicação.");
  }

  const lookup = await db.doc(`referralCodes/${codeUp}`).get();
  if (!lookup.exists) {
    throw new HttpsError("not-found", "Código de indicação inválido.");
  }
  const referrerUid = lookup.get("uid") as string;
  if (referrerUid === uid) {
    throw new HttpsError("failed-precondition", "Não dá pra indicar você mesmo.");
  }

  await userRef.set(
    { indicadoPor: codeUp, indicadoPorUid: referrerUid },
    { merge: true }
  );
  await db.doc(`users/${referrerUid}`).set(
    { indicacoes: FieldValue.increment(1) },
    { merge: true }
  );

  return { ok: true };
});
