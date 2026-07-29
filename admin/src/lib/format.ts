// Formatação pt-BR compartilhada pelas telas.

export const brl = (v: number) =>
  v.toLocaleString("pt-BR", { style: "currency", currency: "BRL" });

/** Data curta; nulo vira travessão. */
export const dia = (d?: Date | null) =>
  d ? d.toLocaleDateString("pt-BR") : "—";

/** O Firestore guarda "cartao" sem acento; a tela mostra com. */
export const metodoLabel = (m?: string | null) =>
  m === "cartao" ? "Cartão" : m === "pix" ? "Pix" : m || "—";
