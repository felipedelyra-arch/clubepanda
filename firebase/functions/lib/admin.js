"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.setAdminRole = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin_1 = require("./lib/admin");
const guards_1 = require("./lib/guards");
/**
 * Concede/revoga a role admin via custom claim.
 * Só um admin existente pode chamar. O primeiro admin deve ser criado
 * manualmente (ver README: firebase auth + setCustomUserClaims via script).
 */
exports.setAdminRole = (0, https_1.onCall)(async (req) => {
    (0, guards_1.requireAdmin)(req);
    const { targetUid, makeAdmin } = req.data;
    if (!targetUid) {
        throw new https_1.HttpsError("invalid-argument", "targetUid obrigatório.");
    }
    const claims = makeAdmin ? { role: "admin" } : { role: null };
    await admin_1.auth.setCustomUserClaims(targetUid, claims);
    // Espelha em Firestore para listar admins no painel.
    await admin_1.db.doc(`users/${targetUid}`).set({ role: makeAdmin ? "admin" : null }, { merge: true });
    return { ok: true, targetUid, isAdmin: !!makeAdmin };
});
//# sourceMappingURL=admin.js.map