import { FieldValue } from "firebase-admin/firestore";
import { db } from "./admin";

/**
 * Registro de conta fechada no salão (`payments` com `tipo: "consumo"`).
 *
 * Mora aqui, e não no webhook, porque entra por duas portas: o PDV chamando
 * `pdvConsumo` e o dono lançando à mão pelo painel (`lancarConsumo`). As duas
 * gravam exatamente o mesmo documento — o que muda é só quem provou que pode.
 */

export interface ItemConsumo {
  nome?: string;
  quantidade?: number | string;
  preco?: number | string;
}

export interface ConsumoInput {
  /** Identificador da comanda. Vira a chave de idempotência. */
  comandaId?: string;

  // ---- identificação do sócio: basta UM destes ----
  codigoSocio?: string;
  cpf?: string;
  uid?: string;

  // ---- a conta ----
  valor?: number | string;
  descontoClube?: number | string;
  mesa?: string | number;
  atendente?: string;
  metodo?: string;
  itens?: ItemConsumo[];
  /** ISO 8601 ou o formato da Teknisa (`DD/MM/YYYY HH:MI:SS`). Ausente = agora. */
  data?: string;
  /** Conta estornada/cancelada depois de enviada. */
  cancelado?: boolean;
}

export type ResultadoConsumo =
  | { ok: true; paymentId: string; userId: string }
  | { ok: true; duplicado: true; paymentId: string }
  | { ok: true; cancelado: true }
  | { ok: true; ignorado: "comanda_desconhecida" | "socio_nao_identificado" }
  | { ok: false; erro: string };

/** Aceita 143.82, "143.82" e "143,82" — PDV manda dos três jeitos. */
export function num(v: unknown): number {
  if (typeof v === "number") return Number.isFinite(v) ? v : 0;
  if (typeof v !== "string") return 0;
  const n = Number(v.trim().replace(/\./g, "").replace(",", "."));
  return Number.isFinite(n) ? n : 0;
}

/**
 * Tipo de recebimento do PDV -> os três valores que o painel entende
 * (`Payment.metodo`). O código externo varia por instalação, então casa por
 * palavra-chave em vez de tabela fixa.
 */
function normalizarMetodo(v: string | undefined): "cartao" | "pix" | "dinheiro" {
  const s = (v ?? "").toLowerCase();
  if (s.includes("pix")) return "pix";
  if (s.includes("dinheiro") || s.includes("especie") || s.includes("espécie")) {
    return "dinheiro";
  }
  if (s.includes("cart") || s.includes("credito") || s.includes("debito")) return "cartao";
  // Sem match: cai em cartão, que é a maioria das contas, mas registra pra
  // alguém corrigir o mapeamento em vez de o relatório mentir em silêncio.
  if (s) console.warn(`[consumo] tipo de recebimento desconhecido: "${v}" -> cartao`);
  return "cartao";
}

/** `DD/MM/YYYY HH:MI:SS` (Teknisa) ou ISO. Data inválida vira `null` = agora. */
function parseData(v: string | undefined): Date | null {
  if (!v) return null;
  const br = v.match(/^(\d{2})\/(\d{2})\/(\d{4})[ T](\d{2}):(\d{2})(?::(\d{2}))?$/);
  if (br) {
    const [, d, m, a, h, min, s] = br;
    // -03:00 fixo: o PDV fica no salão, não em UTC.
    const iso = `${a}-${m}-${d}T${h}:${min}:${s ?? "00"}-03:00`;
    const dt = new Date(iso);
    return isNaN(dt.getTime()) ? null : dt;
  }
  const dt = new Date(v);
  return isNaN(dt.getTime()) ? null : dt;
}

/** Doc id determinístico por comanda — é o que trava a duplicata. */
function idDaComanda(comandaId: string): string {
  return `pdv_${comandaId.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 100)}`;
}

/** Acha o sócio por código de carteirinha, CPF ou uid. `null` se não achou. */
async function acharUsuario(input: ConsumoInput): Promise<string | null> {
  if (input.uid) {
    const snap = await db.doc(`users/${input.uid}`).get();
    if (snap.exists) return snap.id;
  }

  // Carteirinha: leitura direta pelo doc id em `socioCodes` (ver
  // lib/codigoSocio.ts). Sem query, sem índice, sem chance de duplicata.
  if (input.codigoSocio) {
    const codigo = input.codigoSocio.trim().toUpperCase();
    const snap = await db.doc(`socioCodes/${codigo}`).get();
    const uid = snap.get("uid") as string | undefined;
    if (uid) return uid;
  }

  if (input.cpf) {
    const cpf = input.cpf.replace(/\D/g, "");
    if (cpf.length === 11) {
      const snap = await db.collection("users").where("cpf", "==", cpf).limit(1).get();
      if (!snap.empty) return snap.docs[0].id;
    }
  }

  return null;
}

/**
 * Desconto quando não vem informado: percentual do plano ativo do sócio
 * (`plans.descontoPercentual`), aplicado sobre a conta.
 *
 * O valor informado sempre ganha — é onde a conta foi realmente fechada. Isto
 * aqui só evita registrar zero quando o desconto foi dado na mão e ninguém
 * teve como dizer quanto foi.
 */
async function descontoDoPlano(userId: string, valor: number): Promise<number> {
  const subs = await db
    .collection("subscriptions")
    .where("userId", "==", userId)
    .where("status", "==", "active")
    .limit(1)
    .get();
  if (subs.empty) return 0;

  const planId = subs.docs[0].get("planId") as string | undefined;
  if (!planId) return 0;

  const plano = await db.doc(`plans/${planId}`).get();
  const pct = Number(plano.get("descontoPercentual") ?? 0);
  if (!Number.isFinite(pct) || pct <= 0) return 0;

  return Math.round(valor * (pct / 100) * 100) / 100;
}

/**
 * Grava (ou cancela) uma conta de salão.
 *
 * `origem` só serve pro painel distinguir o que veio do PDV do que foi digitado
 * à mão — número conferido por máquina e número conferido por gente merecem
 * peso diferente na hora de fechar o mês.
 */
export async function registrarConsumo(
  input: ConsumoInput,
  origem: "pdv" | "manual"
): Promise<ResultadoConsumo> {
  const comandaId = (input.comandaId ?? "").toString().trim();
  if (!comandaId) return { ok: false, erro: "comandaId obrigatório." };

  const ref = db.doc(`payments/${idDaComanda(comandaId)}`);

  // Estorno: a conta já entrou e depois foi cancelada no caixa.
  if (input.cancelado) {
    const atual = await ref.get();
    if (!atual.exists) return { ok: true, ignorado: "comanda_desconhecida" };
    await ref.update({ status: "cancelado", canceladoEm: FieldValue.serverTimestamp() });
    return { ok: true, cancelado: true };
  }

  const userId = await acharUsuario(input);
  if (!userId) return { ok: true, ignorado: "socio_nao_identificado" };

  const itens = (input.itens ?? [])
    .filter((i) => i && i.nome)
    .map((i) => ({
      nome: String(i.nome),
      quantidade: Math.max(1, Math.round(num(i.quantidade) || 1)),
      preco: num(i.preco),
    }));

  const valor = num(input.valor);
  if (valor <= 0) return { ok: false, erro: "valor deve ser maior que zero." };

  const descontoClube =
    input.descontoClube != null
      ? num(input.descontoClube)
      : await descontoDoPlano(userId, valor);

  const data = parseData(input.data);

  const doc = {
    userId,
    valor,
    metodo: normalizarMetodo(input.metodo),
    status: "aprovado",
    tipo: "consumo" as const,
    mesa: input.mesa != null && input.mesa !== "" ? String(input.mesa) : null,
    atendente: input.atendente || null,
    itens: itens.length ? itens : null,
    descontoClube,
    origem,
    gatewayRef: comandaId,
    data: data ?? FieldValue.serverTimestamp(),
    criadoEm: FieldValue.serverTimestamp(),
  };

  // `create` (e não `set`) é o ponto da idempotência: reenvio da mesma comanda
  // estoura ALREADY_EXISTS e é respondido como sucesso.
  try {
    await ref.create(doc);
  } catch (err) {
    if ((err as { code?: number }).code === 6) {
      return { ok: true, duplicado: true, paymentId: ref.id };
    }
    throw err;
  }

  return { ok: true, paymentId: ref.id, userId };
}
