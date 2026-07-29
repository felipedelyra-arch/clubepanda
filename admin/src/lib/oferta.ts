// Janela de validade das ofertas — mesma regra que o app aplica em
// `Promotion.vigenteEm` (app/lib/core/models/models.dart). Se mudar aqui,
// mude lá.

export type StatusOferta = "inativa" | "agendada" | "no ar" | "encerrada";

export interface JanelaOferta {
  ativa?: boolean;
  validadeInicio?: Date | null;
  validadeFim?: Date | null;
}

/** Em que fase a oferta está agora. */
export function statusOferta(
  o: JanelaOferta,
  agora: Date = new Date()
): StatusOferta {
  if (o.ativa === false) return "inativa";
  if (o.validadeInicio && agora < o.validadeInicio) return "agendada";
  if (o.validadeFim && agora > o.validadeFim) return "encerrada";
  return "no ar";
}

export const corStatus: Record<StatusOferta, "green" | "orange" | "gray" | "red"> = {
  "no ar": "green",
  agendada: "orange",
  encerrada: "gray",
  inativa: "gray",
};

const dataHora = (d: Date) =>
  d.toLocaleString("pt-BR", {
    day: "2-digit",
    month: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });

/** Frase curta da janela, pro dono conferir sem abrir o formulário. */
export function janelaTexto(o: JanelaOferta): string {
  if (!o.validadeInicio && !o.validadeFim) return "Sem prazo — fica no ar até você desligar";
  if (o.validadeInicio && o.validadeFim)
    return `${dataHora(o.validadeInicio)} até ${dataHora(o.validadeFim)}`;
  if (o.validadeFim) return `Até ${dataHora(o.validadeFim)}`;
  return `A partir de ${dataHora(o.validadeInicio!)}`;
}

/** Date -> valor de `<input type="datetime-local">` (fuso local). */
export function toLocalInput(d?: Date | null): string {
  if (!d) return "";
  const local = new Date(d.getTime() - d.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 16);
}

/** Valor de `<input type="datetime-local">` -> Date. Vazio vira null. */
export function fromLocalInput(v: string): Date | null {
  if (!v) return null;
  const d = new Date(v);
  return isNaN(d.getTime()) ? null : d;
}
