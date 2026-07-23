"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.stripe = stripe;
const stripe_1 = __importDefault(require("stripe"));
let _stripe = null;
/** Instância Stripe lazy (lê secret do env só quando usada). */
function stripe() {
    if (!_stripe) {
        const key = process.env.STRIPE_SECRET_KEY;
        if (!key)
            throw new Error("STRIPE_SECRET_KEY não configurada.");
        // Usa a apiVersion default da lib instalada (evita pin quebrar no upgrade).
        _stripe = new stripe_1.default(key);
    }
    return _stripe;
}
//# sourceMappingURL=stripe.js.map