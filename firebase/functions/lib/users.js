"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onAuthUserCreate = void 0;
const identity_1 = require("firebase-functions/v2/identity");
const admin_1 = require("./lib/admin");
const firestore_1 = require("firebase-admin/firestore");
/**
 * Ao criar conta (Auth), garante o doc de perfil em users/ com pontos zerados.
 * Escrita pelo backend => ignora rules, mas mantém consistência.
 */
exports.onAuthUserCreate = (0, identity_1.beforeUserCreated)(async (event) => {
    const user = event.data;
    if (!user)
        return;
    const ref = admin_1.db.doc(`users/${user.uid}`);
    const snap = await ref.get();
    if (!snap.exists) {
        await ref.set({
            uid: user.uid,
            nome: user.displayName ?? "",
            email: user.email ?? "",
            telefone: user.phoneNumber ?? "",
            endereco: null,
            fcmToken: null,
            pontos: 0,
            role: null,
            criadoEm: firestore_1.FieldValue.serverTimestamp(),
        });
    }
    return;
});
//# sourceMappingURL=users.js.map