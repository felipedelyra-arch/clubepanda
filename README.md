# Clube Panda — Tio Panda 🐼🍣

Clube de assinatura do restaurante japonês **Tio Panda**. Cliente paga mensalidade e ganha
promoções e premiações (rodízios, pratos, sobremesas, brindes, cupons) lançadas pelo dono.

## Arquitetura

Monorepo com **um backend Firebase** compartilhado por duas aplicações:

| Pasta | O quê | Stack |
|---|---|---|
| `firebase/` | Backend único | Firestore, Auth, Cloud Functions (TS), Storage, Cloud Messaging |
| `app/` | App do Cliente (iOS/Android) | Flutter + Riverpod + go_router |
| `admin/` | Painel do Admin (web) | React + TypeScript + Vite + Tailwind |

Painel e app conversam pelo **mesmo Firestore em tempo real**.

## Ordem de execução

1. **Firebase** — projeto, Auth, Firestore + coleções, Storage, Security Rules. ✅ base
2. **Cloud Functions** — custom claim `role:admin`, webhooks pagamento (Stripe + Pix),
   criar/sincronizar assinatura, conceder admin, enviar push. ✅ base
3. **App Flutter** — design system → auth → home → premiações → assinatura → perfil → push.
4. **Admin React** — auth+guarda admin → layout → dashboard → promoções → premiações →
   planos → membros → pagamentos → notificações → config.

## Modelo de dados (Firestore)

`users`, `subscriptions`, `plans`, `promotions`, `rewards`, `redemptions`, `payments`.
Detalhe em [`firebase/firestore.rules`](firebase/firestore.rules) e nos READMEs de cada projeto.

## Segurança (regra de ouro)

Cobrança, criação de assinatura, concessão de admin, envio de push e validação de pagamento
rodam **apenas em Cloud Functions**. Cliente nunca escreve isso direto.

## Setup rápido

```bash
# 1. Backend
cd firebase && npm --prefix functions install
firebase login && firebase use --add          # selecione seu projeto
firebase deploy --only firestore:rules,storage,functions

# 2. Admin
cd ../admin && npm install && npm run dev

# 3. App (requer Flutter SDK instalado)
cd ../app && flutter pub get && flutter run
```

Variáveis de ambiente: copie cada `.env.example` para `.env` e preencha.

## Identidade visual

Paleta laranja Tio Panda (`#F47A20`), preto panda (`#1A1A1A`), tema claro/escuro.
Tipografia Poppins/Inter. Design system compartilhado em código nas duas apps.
