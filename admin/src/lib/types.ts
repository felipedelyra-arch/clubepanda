// Tipos espelhando as coleções Firestore (mesmo backend do app).

export interface AppUser {
  uid: string;
  nome: string;
  email: string;
  telefone?: string;
  endereco?: string | null;
  pontos: number;
  role?: string | null;
  criadoEm?: Date | null;
}

export interface Plan {
  id: string;
  nome: string;
  preco: number;
  intervalo: "mensal" | "trimestral" | "anual";
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
  custoPontos: number;
  tipo: RewardTipo;
  estoque: number;
  apenasAssinantes: boolean;
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

export interface Payment {
  id: string;
  userId: string;
  valor: number;
  metodo: "cartao" | "pix";
  status: string;
  gatewayRef?: string | null;
  data?: Date | null;
}
