"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.messaging = exports.auth = exports.db = void 0;
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const auth_1 = require("firebase-admin/auth");
const messaging_1 = require("firebase-admin/messaging");
// Inicializa o Admin SDK uma única vez (frio ou reuso de instância).
if ((0, app_1.getApps)().length === 0) {
    (0, app_1.initializeApp)();
}
exports.db = (0, firestore_1.getFirestore)();
exports.auth = (0, auth_1.getAuth)();
exports.messaging = (0, messaging_1.getMessaging)();
//# sourceMappingURL=admin.js.map