import { beforeUserCreated } from "firebase-functions/v2/identity";
import { db } from "./lib/admin";
import { FieldValue } from "firebase-admin/firestore";

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
  return;
});
