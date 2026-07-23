"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requireAuth = requireAuth;
exports.requireAdmin = requireAdmin;
const https_1 = require("firebase-functions/v2/https");
/** Garante que o chamador está autenticado; retorna o uid. */
function requireAuth(req) {
    if (!req.auth) {
        throw new https_1.HttpsError("unauthenticated", "Precisa estar autenticado.");
    }
    return req.auth.uid;
}
/** Garante que o chamador é admin (custom claim role=admin). */
function requireAdmin(req) {
    const uid = requireAuth(req);
    if (req.auth?.token?.role !== "admin") {
        throw new https_1.HttpsError("permission-denied", "Acesso restrito a administradores.");
    }
    return uid;
}
//# sourceMappingURL=guards.js.map