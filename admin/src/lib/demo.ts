// Modo demo/mock — liga com VITE_DEMO=true no .env.
// Bypassa auth (admin fake) e injeta dados fictícios nas telas, sem backend.
// Mutações (salvar/excluir/push) viram no-op com toast, não tocam Firebase.

import { toast } from "sonner";
import type {
  AppUser,
  Plan,
  Promotion,
  Reward,
  Redemption,
  Subscription,
  Payment,
  Restaurante,
} from "./types";

export const IS_DEMO = import.meta.env.VITE_DEMO === "true";

/**
 * No modo demo: mostra toast informando que é demo e retorna true (o chamador
 * deve dar `return` sem tocar o backend). Fora do demo: retorna false.
 */
export function demoBlock(msg = "Ação desativada no modo demo"): boolean {
  if (IS_DEMO) {
    toast.info(`${msg} 🐼 (modo demo)`);
    return true;
  }
  return false;
}

const now = new Date();
const mes = (m: number, d = 10) => new Date(now.getFullYear(), m, d);
const diasAtras = (n: number) =>
  new Date(now.getTime() - n * 24 * 60 * 60 * 1000);

const demoUsers: AppUser[] = [
  { uid: "u_ana", nome: "Ana Souza", email: "ana@email.com", telefone: "(14) 99911-0001", criadoEm: mes(0, 5) },
  { uid: "u_bruno", nome: "Bruno Lima", email: "bruno@email.com", telefone: "(14) 99911-0002", criadoEm: mes(1, 12) },
  { uid: "u_carla", nome: "Carla Dias", email: "carla@email.com", telefone: "(14) 99911-0003", criadoEm: mes(2, 3) },
  { uid: "u_diego", nome: "Diego Rocha", email: "diego@email.com", telefone: "(14) 99911-0004", criadoEm: mes(3, 20) },
  { uid: "u_elis", nome: "Elis Prado", email: "elis@email.com", telefone: "(14) 99911-0005", criadoEm: mes(4, 8) },
  { uid: "u_fabio", nome: "Fábio Nunes", email: "fabio@email.com", telefone: "(14) 99911-0006", criadoEm: mes(5, 14) },
  { uid: "u_gina", nome: "Gina Melo", email: "gina@email.com", telefone: "(14) 99911-0007", criadoEm: mes(6, 2) },
  { uid: "u_admin", nome: "Tio Panda (você)", email: "admin@tiopanda.com.br", telefone: "", role: "admin", criadoEm: mes(0, 1) },
];

// Plano é um só, então toda assinatura aponta pra `p_mensal`.
const demoSubs: Subscription[] = [
  { id: "s1", userId: "u_ana", planId: "p_mensal", status: "active", proximaCobranca: diasAtras(-20), formaPagamento: "cartao" },
  { id: "s2", userId: "u_carla", planId: "p_mensal", status: "active", proximaCobranca: diasAtras(-12), formaPagamento: "cartao" },
  { id: "s3", userId: "u_elis", planId: "p_mensal", status: "active", proximaCobranca: diasAtras(-8), formaPagamento: "pix" },
  { id: "s4", userId: "u_gina", planId: "p_mensal", status: "active", proximaCobranca: diasAtras(-25), formaPagamento: "cartao" },
  { id: "s5", userId: "u_bruno", planId: "p_mensal", status: "canceled", proximaCobranca: null, formaPagamento: "cartao" },
];

// Mensalidade única de R$ 4,90.
const demoPayments: Payment[] = [
  { id: "pay1", userId: "u_ana", valor: 4.9, metodo: "cartao", status: "aprovado", gatewayRef: "in_1AbcDef", data: mes(now.getMonth()) },
  { id: "pay2", userId: "u_carla", valor: 4.9, metodo: "cartao", status: "aprovado", gatewayRef: "in_2GhiJkl", data: mes(now.getMonth(), 2) },
  { id: "pay3", userId: "u_elis", valor: 4.9, metodo: "pix", status: "aprovado", gatewayRef: "pix_abc123", data: mes(now.getMonth(), 4) },
  { id: "pay4", userId: "u_gina", valor: 4.9, metodo: "cartao", status: "aprovado", gatewayRef: "in_3MnoPqr", data: mes(Math.max(0, now.getMonth() - 1), 15) },
  { id: "pay5", userId: "u_bruno", valor: 4.9, metodo: "cartao", status: "recusado", gatewayRef: "in_4StuVwx", data: mes(Math.max(0, now.getMonth() - 1), 18) },
  { id: "pay6", userId: "u_ana", valor: 4.9, metodo: "cartao", status: "aprovado", gatewayRef: "in_5YzaBcd", data: mes(Math.max(0, now.getMonth() - 2), 10) },
];

const horas = (n: number) => new Date(now.getTime() + n * 60 * 60 * 1000);

// Espelha os mesmos casos do demo do app (app/lib/core/demo.dart): no ar
// terminando hoje, no ar com folga, sem prazo, agendada e encerrada.
const demoPromotions: Promotion[] = [
  { id: "promo1", titulo: "Rodízio com 20% OFF", descricao: "Toda quarta, rodízio completo com desconto pra assinantes.", ativa: true, apenasAssinantes: true, imagem: null, validadeInicio: null, validadeFim: horas(6) },
  { id: "promo2", titulo: "Temaki em dobro", descricao: "Compre 1 temaki e leve 2 na sexta-feira.", ativa: true, apenasAssinantes: false, imagem: null, validadeInicio: null, validadeFim: horas(72) },
  { id: "promo3", titulo: "Combo família", descricao: "40 peças + 2 refrigerantes por um preço especial.", ativa: true, apenasAssinantes: false, imagem: null, validadeInicio: null, validadeFim: null },
  { id: "promo4", titulo: "Festival de sashimi", descricao: "Começa amanhã — sashimi especial a preço de entrada.", ativa: true, apenasAssinantes: false, imagem: null, validadeInicio: horas(24), validadeFim: horas(120) },
  { id: "promo5", titulo: "Quarta do hot roll", descricao: "Promoção da semana passada, já encerrada.", ativa: true, apenasAssinantes: false, imagem: null, validadeInicio: horas(-192), validadeFim: horas(-24) },
];

const demoRewards: Reward[] = [
  { id: "rw1", titulo: "Rodízio grátis", descricao: "Um rodízio completo por nossa conta.", tipo: "rodizio", estoque: 10, resgatavelAte: diasAtras(-3), imagem: null },
  { id: "rw2", titulo: "Sushi especial do chef", descricao: "Combinado exclusivo de 12 peças.", tipo: "prato", estoque: 20, resgatavelAte: diasAtras(-1), imagem: null },
  { id: "rw3", titulo: "Sorvete de matchá", descricao: "Sobremesa tradicional japonesa.", tipo: "sobremesa", estoque: 0, resgatavelAte: null, imagem: null },
  { id: "rw4", titulo: "Saquê de boas-vindas", descricao: "Brinde pra quem é sócio.", tipo: "cupom", estoque: 50, resgatavelAte: null, imagem: null },
];

const demoRedemptions: Redemption[] = [
  { id: "rd1", userId: "u_ana", rewardId: "rw2", rewardTitulo: "Sushi especial do chef", codigo: "A1B2C3D4E5F6", status: "disponivel", criadoEm: diasAtras(1) },
  { id: "rd2", userId: "u_carla", rewardId: "rw1", rewardTitulo: "Rodízio grátis", codigo: "F6E5D4C3B2A1", status: "disponivel", criadoEm: diasAtras(2) },
  { id: "rd3", userId: "u_gina", rewardId: "rw3", rewardTitulo: "Sorvete de matchá", codigo: "9Z8Y7X6W5V4U", status: "usado", criadoEm: diasAtras(9) },
];

// Plano único de R$ 4,90/mês — mesmos dados de `app/lib/core/demo.dart`.
const demoPlans: Plan[] = [
  {
    id: "p_mensal",
    nome: "Clube Panda",
    preco: 4.9,
    intervalo: "mês",
    beneficios: [
      "Descontos e promoções exclusivas todo mês",
      "Prêmios e pratos liberados pelo restaurante",
      "Sobremesa grátis no seu aniversário",
      "Sem fidelidade — cancele quando quiser",
    ],
    recomendado: true,
    stripePriceId: "price_demo_mensal",
  },
];

const demoRestaurante: Restaurante = {
  nome: "Tio Panda",
  telefone: "551430000000",
  whatsapp: "5514990000000",
  endereco: "Tio Panda restaurante",
  politicaPrivacidadeUrl: "https://tiopanda.com.br/privacidade",
  termosUrl: "https://tiopanda.com.br/termos",
  playStoreUrl: "https://play.google.com/store/apps/details?id=com.tiopanda.clube",
  appStoreUrl: "https://apps.apple.com/app/id000000000",
};

// Mapa caminho do documento -> dado mock.
export const demoDocs: Record<string, unknown> = {
  "config/restaurante": demoRestaurante,
};

// Mapa caminho da coleção -> dados mock.
export const demoData: Record<string, unknown[]> = {
  users: demoUsers,
  subscriptions: demoSubs,
  payments: demoPayments,
  promotions: demoPromotions,
  rewards: demoRewards,
  redemptions: demoRedemptions,
  plans: demoPlans,
};

// Usuário admin fake pro AuthContext no modo demo.
export const demoAdminUser = {
  uid: "u_admin",
  email: "admin@tiopanda.com.br",
  displayName: "Tio Panda",
} as const;
