import { onCall, HttpsError } from "firebase-functions/v2/https";
import { auth, db } from "./lib/admin";
import { requireAdmin } from "./lib/guards";
import { consumir } from "./lib/rateLimit";

/**
 * Concede/revoga a role admin via custom claim.
 * Só um admin existente pode chamar. O primeiro admin deve ser criado
 * manualmente (ver README: firebase auth + setCustomUserClaims via script).
 */
export const setAdminRole = onCall(async (req) => {
  const chamador = requireAdmin(req);
  await consumir(chamador, "setAdminRole");

  const { targetUid, makeAdmin } = req.data as {
    targetUid?: string;
    makeAdmin?: boolean;
  };
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "targetUid obrigatório.");
  }

  const claims = makeAdmin ? { role: "admin" } : { role: null };
  await auth.setCustomUserClaims(targetUid, claims);

  // Espelha em Firestore para listar admins no painel.
  await db.doc(`users/${targetUid}`).set(
    { role: makeAdmin ? "admin" : null },
    { merge: true }
  );

  return { ok: true, targetUid, isAdmin: !!makeAdmin };
});
