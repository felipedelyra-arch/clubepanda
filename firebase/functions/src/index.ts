/**
 * Clube Panda — Cloud Functions (entry point).
 * Região padrão: southamerica-east1 (São Paulo).
 */
import { setGlobalOptions } from "firebase-functions/v2";

setGlobalOptions({ region: "southamerica-east1", maxInstances: 10 });

// Auth / admin
export { setAdminRole } from "./admin";
export { onAuthUserCreate } from "./users";
export { deleteAccount } from "./account";
export { ensureReferralCode, applyReferral } from "./referral";

// Assinatura (Stripe)
export { createCheckoutSession, cancelSubscription } from "./subscriptions";

// Premiações
export { redeemReward, validateRedemption } from "./redemptions";

// Push (FCM) + central de avisos do app
export {
  sendPush,
  onPromotionCreated,
  publicarPromocoesAgendadas,
  onRewardCreated,
} from "./push";

// Webhooks de pagamento
export { stripeWebhook } from "./webhooks/stripe";
export { pixWebhook } from "./webhooks/pix";
