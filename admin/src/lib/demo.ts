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
  { uid: "u_ana", nome: "Ana Souza", email: "ana@email.com", telefone: "(14) 99911-0001", pontos: 320, criadoEm: mes(0, 5) },
  { uid: "u_bruno", nome: "Bruno Lima", email: "bruno@email.com", telefone: "(14) 99911-0002", pontos: 80, criadoEm: mes(1, 12) },
  { uid: "u_carla", nome: "Carla Dias", email: "carla@email.com", telefone: "(14) 99911-0003", pontos: 540, criadoEm: mes(2, 3) },
  { uid: "u_diego", nome: "Diego Rocha", email: "diego@email.com", telefone: "(14) 99911-0004", pontos: 15, criadoEm: mes(3, 20) },
  { uid: "u_elis", nome: "Elis Prado", email: "elis@email.com", telefone: "(14) 99911-0005", pontos: 210, criadoEm: mes(4, 8) },
  { uid: "u_fabio", nome: "Fábio Nunes", email: "fabio@email.com", telefone: "(14) 99911-0006", pontos: 0, criadoEm: mes(5, 14) },
  { uid: "u_gina", nome: "Gina Melo", email: "gina@email.com", telefone: "(14) 99911-0007", pontos: 690, criadoEm: mes(6, 2) },
  { uid: "u_admin", nome: "Tio Panda (você)", email: "admin@tiopanda.com.br", telefone: "", pontos: 0, role: "admin", criadoEm: mes(0, 1) },
];

const demoSubs: Subscription[] = [
  { id: "s1", userId: "u_ana", planId: "p_mensal", status: "active", proximaCobranca: diasAtras(-20), formaPagamento: "cartao" },
  { id: "s2", userId: "u_carla", planId: "p_anual", status: "active", proximaCobranca: diasAtras(-200), formaPagamento: "cartao" },
  { id: "s3", userId: "u_elis", planId: "p_mensal", status: "active", proximaCobranca: diasAtras(-8), formaPagamento: "pix" },
  { id: "s4", userId: "u_gina", planId: "p_trimestral", status: "active", proximaCobranca: diasAtras(-60), formaPagamento: "cartao" },
  { id: "s5", userId: "u_bruno", planId: "p_mensal", status: "canceled", proximaCobranca: null, formaPagamento: "cartao" },
];

const demoPayments: Payment[] = [
  { id: "pay1", userId: "u_ana", valor: 49.9, metodo: "cartao", status: "aprovado", gatewayRef: "in_1AbcDef", data: mes(now.getMonth()) },
  { id: "pay2", userId: "u_carla", valor: 499.0, metodo: "cartao", status: "aprovado", gatewayRef: "in_2GhiJkl", data: mes(now.getMonth(), 2) },
  { id: "pay3", userId: "u_elis", valor: 49.9, metodo: "pix", status: "aprovado", gatewayRef: "pix_abc123", data: mes(now.getMonth(), 4) },
  { id: "pay4", userId: "u_gina", valor: 129.9, metodo: "cartao", status: "aprovado", gatewayRef: "in_3MnoPqr", data: mes(Math.max(0, now.getMonth() - 1), 15) },
  { id: "pay5", userId: "u_bruno", valor: 49.9, metodo: "cartao", status: "recusado", gatewayRef: "in_4StuVwx", data: mes(Math.max(0, now.getMonth() - 1), 18) },
  { id: "pay6", userId: "u_ana", valor: 49.9, metodo: "cartao", status: "aprovado", gatewayRef: "in_5YzaBcd", data: mes(Math.max(0, now.getMonth() - 2), 10) },
];

const demoPromotions: Promotion[] = [
  { id: "promo1", titulo: "Rodízio com 20% OFF", descricao: "Toda quarta, rodízio completo com desconto pra assinantes.", ativa: true, apenasAssinantes: true, imagem: null },
  { id: "promo2", titulo: "Temaki em dobro", descricao: "Compre 1 temaki e leve 2 na sexta-feira.", ativa: true, apenasAssinantes: false, imagem: null },
  { id: "promo3", titulo: "Sobremesa grátis", descricao: "Sorvete de matchá grátis acima de R$ 80.", ativa: false, apenasAssinantes: false, imagem: null },
];

const demoRewards: Reward[] = [
  { id: "rw1", titulo: "Rodízio grátis", descricao: "Um rodízio completo por nossa conta.", tipo: "rodizio", custoPontos: 500, estoque: 10, apenasAssinantes: false, imagem: null },
  { id: "rw2", titulo: "Sushi especial do chef", descricao: "Combinado exclusivo de 12 peças.", tipo: "prato", custoPontos: 250, estoque: 20, apenasAssinantes: false, imagem: null },
  { id: "rw3", titulo: "Sorvete de matchá", descricao: "Sobremesa tradicional japonesa.", tipo: "sobremesa", custoPontos: 100, estoque: 0, apenasAssinantes: false, imagem: null },
  { id: "rw4", titulo: "Saquê de boas-vindas", descricao: "Exclusivo pra assinantes.", tipo: "cupom", custoPontos: 0, estoque: 50, apenasAssinantes: true, imagem: null },
];

const demoRedemptions: Redemption[] = [
  { id: "rd1", userId: "u_ana", rewardId: "rw2", rewardTitulo: "Sushi especial do chef", codigo: "A1B2C3D4E5F6", status: "disponivel", criadoEm: diasAtras(1) },
  { id: "rd2", userId: "u_carla", rewardId: "rw1", rewardTitulo: "Rodízio grátis", codigo: "F6E5D4C3B2A1", status: "disponivel", criadoEm: diasAtras(2) },
  { id: "rd3", userId: "u_gina", rewardId: "rw3", rewardTitulo: "Sorvete de matchá", codigo: "9Z8Y7X6W5V4U", status: "usado", criadoEm: diasAtras(9) },
];

const demoPlans: Plan[] = [
  { id: "p_mensal", nome: "Mensal", preco: 49.9, intervalo: "mensal", beneficios: ["Promoções exclusivas", "Acúmulo de pontos", "1 sobremesa grátis/mês"], recomendado: false, stripePriceId: "price_demo_mensal" },
  { id: "p_trimestral", nome: "Trimestral", preco: 129.9, intervalo: "trimestral", beneficios: ["Tudo do Mensal", "Rodízio grátis no aniversário", "Prioridade no delivery"], recomendado: true, stripePriceId: "price_demo_tri" },
  { id: "p_anual", nome: "Anual", preco: 499.0, intervalo: "anual", beneficios: ["Tudo do Trimestral", "2 rodízios grátis", "Brinde de boas-vindas"], recomendado: false, stripePriceId: "price_demo_anual" },
];

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
