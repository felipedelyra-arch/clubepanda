import Stripe from "stripe";

let _stripe: Stripe | null = null;

/** Instância Stripe lazy (lê secret do env só quando usada). */
export function stripe(): Stripe {
  if (!_stripe) {
    const key = process.env.STRIPE_SECRET_KEY;
    if (!key) throw new Error("STRIPE_SECRET_KEY não configurada.");
    // Usa a apiVersion default da lib instalada (evita pin quebrar no upgrade).
    _stripe = new Stripe(key);
  }
  return _stripe;
}
