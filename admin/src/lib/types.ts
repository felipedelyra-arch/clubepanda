// Tipos espelhando as coleções Firestore (mesmo backend do app).

export interface AppUser {
  uid: string;
  nome: string;
  email: string;
  telefone?: string;
  endereco?: string | null;
  role?: string | null;
  criadoEm?: Date | null;
}

export interface Plan {
  id: string;
  nome: string;
  preco: number;
  /**
   * Aparece cru no app: `R$ 4,90 / mês` (plans_screen.dart). Por isso é o
   * substantivo do período, não o adjetivo — "mensal" imprimiria "/ mensal".
   */
  intervalo: "mês" | "trimestre" | "ano";
  beneficios: string[];
  recomendado?: boolean;
  stripePriceId?: string | null;
  ativo?: boolean;
}

export interface Promotion {
  id: string;
  titulo: string;
  descricao: string;
  imagem?: string | null;
  ativa: boolean;
  apenasAssinantes: boolean;
  validadeInicio?: Date | null;
  validadeFim?: Date | null;
}

export type RewardTipo = "rodizio" | "prato" | "sobremesa" | "cupom";

export interface Reward {
  id: string;
  titulo: string;
  descricao: string;
  imagem?: string | null;
  tipo: RewardTipo;
  estoque: number;
  /** Prazo limite pra resgatar (definido pelo dono). Nulo = sem prazo. */
  resgatavelAte?: Date | null;
}

export interface Redemption {
  id: string;
  userId: string;
  rewardId: string;
  rewardTitulo: string;
  codigo: string;
  status: "disponivel" | "usado" | "expirado";
  criadoEm?: Date | null;
}

export interface Subscription {
  id: string;
  userId: string;
  planId: string;
  status: "active" | "canceled" | "past_due";
  proximaCobranca?: Date | null;
  formaPagamento?: string | null;
}

/**
 * Doc `config/restaurante`. Espelha `app/lib/core/restaurante.dart` — a ideia é
 * o app passar a ler daqui em vez das constantes compiladas.
 */
export interface Restaurante {
  nome: string;
  /** Telefone pra ligação, só dígitos com DDI: 5514... */
  telefone: string;
  /** WhatsApp no formato wa.me, só dígitos com DDI. */
  whatsapp: string;
  /** Endereço usado na busca do Google Maps. */
  endereco: string;
  politicaPrivacidadeUrl: string;
  termosUrl: string;
  playStoreUrl: string;
  appStoreUrl: string;
}

export interface Payment {
  id: string;
  userId: string;
  valor: number;
  metodo: "cartao" | "pix";
  status: string;
  gatewayRef?: string | null;
  data?: Date | null;
}
