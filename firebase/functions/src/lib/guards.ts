import { HttpsError, CallableRequest } from "firebase-functions/v2/https";

/**
 * Exige App Check nas chamadas? Ligado por variável de ambiente, e desligado
 * por padrão de propósito.
 *
 * O App Check já está instalado no app (`app/lib/main.dart`), mas só no Android
 * e no iOS — na web o provedor é reCAPTCHA e depende de uma chave de site que
 * ainda não foi criada. Ligar isto hoje derrubaria o painel do dono e o build
 * web do app, que são justamente os que não mandam token.
 *
 * Quando a chave reCAPTCHA existir e o painel também ativar o App Check:
 *
 *   1. `REQUER_APP_CHECK=true` no `.env` das functions;
 *   2. impor no console (Firebase > App Check), que fecha também o acesso
 *      direto ao Firestore e ao Storage pelos SDKs.
 *
 * Enquanto está desligado, o token continua sendo enviado e ignorado — que é
 * exatamente o pré-requisito pra poder impor depois sem quebrar ninguém.
 */
const REQUER_APP_CHECK = process.env.REQUER_APP_CHECK === "true";

/**
 * Recusa a chamada que não trouxe token de App Check válido.
 *
 * É a peça que o limite de chamada (`lib/rateLimit.ts`) não cobre: o limite
 * segura o estrago por conta, isto aqui segura quem cria contas em série a
 * partir de um script com a chave de API copiada do APK.
 */
export function requireAppCheck(req: CallableRequest): void {
  if (!REQUER_APP_CHECK) return;
  if (!req.app) {
    throw new HttpsError(
      "failed-precondition",
      "Chamada sem verificação de app. Atualize o aplicativo."
    );
  }
}

/** Garante que o chamador está autenticado; retorna o uid. */
export function requireAuth(req: CallableRequest): string {
  requireAppCheck(req);
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
