import { HttpsError, CallableRequest } from "firebase-functions/v2/https";

/** Garante que o chamador está autenticado; retorna o uid. */
export function requireAuth(req: CallableRequest): string {
  if (!req.auth) {
    throw new HttpsError("unauthenticated", "Precisa estar autenticado.");
  }
  return req.auth.uid;
}

/** Garante que o chamador é admin (custom claim role=admin). */
export function requireAdmin(req: CallableRequest): string {
  const uid = requireAuth(req);
  if (req.auth?.token?.role !== "admin") {
    throw new HttpsError("permission-denied", "Acesso restrito a administradores.");
  }
  return uid;
}
