"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.pixWebhook = exports.stripeWebhook = exports.onPromotionCreated = exports.sendPush = exports.validateRedemption = exports.redeemReward = exports.cancelSubscription = exports.createCheckoutSession = exports.onAuthUserCreate = exports.setAdminRole = void 0;
/**
 * Clube Panda — Cloud Functions (entry point).
 * Região padrão: southamerica-east1 (São Paulo).
 */
const v2_1 = require("firebase-functions/v2");
(0, v2_1.setGlobalOptions)({ region: "southamerica-east1", maxInstances: 10 });
// Auth / admin
var admin_1 = require("./admin");
Object.defineProperty(exports, "setAdminRole", { enumerable: true, get: function () { return admin_1.setAdminRole; } });
var users_1 = require("./users");
Object.defineProperty(exports, "onAuthUserCreate", { enumerable: true, get: function () { return users_1.onAuthUserCreate; } });
// Assinatura (Stripe)
var subscriptions_1 = require("./subscriptions");
Object.defineProperty(exports, "createCheckoutSession", { enumerable: true, get: function () { return subscriptions_1.createCheckoutSession; } });
Object.defineProperty(exports, "cancelSubscription", { enumerable: true, get: function () { return subscriptions_1.cancelSubscription; } });
// Premiações
var redemptions_1 = require("./redemptions");
Object.defineProperty(exports, "redeemReward", { enumerable: true, get: function () { return redemptions_1.redeemReward; } });
Object.defineProperty(exports, "validateRedemption", { enumerable: true, get: function () { return redemptions_1.validateRedemption; } });
// Push (FCM)
var push_1 = require("./push");
Object.defineProperty(exports, "sendPush", { enumerable: true, get: function () { return push_1.sendPush; } });
Object.defineProperty(exports, "onPromotionCreated", { enumerable: true, get: function () { return push_1.onPromotionCreated; } });
// Webhooks de pagamento
var stripe_1 = require("./webhooks/stripe");
Object.defineProperty(exports, "stripeWebhook", { enumerable: true, get: function () { return stripe_1.stripeWebhook; } });
var pix_1 = require("./webhooks/pix");
Object.defineProperty(exports, "pixWebhook", { enumerable: true, get: function () { return pix_1.pixWebhook; } });
//# sourceMappingURL=index.js.map