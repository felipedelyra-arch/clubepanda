# Clube Panda — Backend Firebase

Backend único compartilhado pelo app (Flutter) e pelo painel (React).

## Serviços

- **Auth** — email/senha (e provedores extras se quiser).
- **Firestore** — coleções `users`, `subscriptions`, `plans`, `promotions`, `rewards`, `redemptions`, `payments`.
- **Cloud Functions** (TS, região `southamerica-east1`).
- **Storage** — imagens de promoções/premiações/perfil.
- **Cloud Messaging** — push.

## Setup

```bash
# 1. Instalar CLI e logar
npm i -g firebase-tools
firebase login

# 2. Criar/selecionar projeto
firebase projects:create clube-panda   # ou use um existente
firebase use --add

# 3. Dependências das functions
npm --prefix functions install

# 4. Env das functions
cp functions/.env.example functions/.env   # preencha Stripe/Pix

# 5. Deploy
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

## Primeiro admin (bootstrap)

Custom claim `role:admin` só é concedida por outro admin. O primeiro é manual:

```bash
# baixe a service account key -> firebase/serviceAccountKey.json
node scripts/set-first-admin.js <UID_DO_USUARIO>
```

Depois, novos admins pela função `setAdminRole` (painel > Configurações).

## Cloud Functions

| Função | Tipo | O quê |
|---|---|---|
| `setAdminRole` | callable (admin) | concede/revoga `role:admin` |
| `onAuthUserCreate` | trigger auth | cria doc `users/{uid}` com pontos=0 |
| `createCheckoutSession` | callable | inicia assinatura Stripe (retorna URL) |
| `cancelSubscription` | callable | cancela no fim do período |
| `redeemReward` | callable | resgata premiação (transação: pontos+estoque) |
| `validateRedemption` | callable (admin) | marca resgate como usado |
| `sendPush` | callable (admin) | push p/ todos ou só assinantes |
| `onPromotionCreated` | trigger firestore | push automático em nova promoção ativa |
| `stripeWebhook` | HTTPS | valida pagamento cartão, grava payment/subscription |
| `pixWebhook` | HTTPS | valida pagamento Pix (ajustar ao gateway) |

### Webhooks

- **Stripe:** aponte para `https://<region>-<project>.cloudfunctions.net/stripeWebhook`.
  Copie o signing secret para `STRIPE_WEBHOOK_SECRET`.
- **Pix:** aponte o gateway para `.../pixWebhook`. Ajuste parsing/assinatura ao provedor.

## Emuladores (dev local)

```bash
npm --prefix functions run build
firebase emulators:start
```

## Hosting do Painel Admin

O `firebase.json` já tem a seção `hosting` configurada: serve `admin/dist`,
faz build automático no deploy (`predeploy`) e trata SPA (rewrite `** -> /index.html`).

**Pré-requisito (o sócio faz quando tiver o projeto):**

1. Preencher `admin/.env` com as chaves do app Web do Firebase.
2. Preencher `functions/.env` com Stripe/Pix.
3. Logar e selecionar o projeto:

```bash
firebase login
firebase use --add          # escolhe o projeto real

# deploy do painel (roda npm install + build do admin sozinho)
firebase deploy --only hosting

# ou tudo de uma vez
firebase deploy --only hosting,functions,firestore:rules,firestore:indexes,storage
```

O painel fica em `https://<projeto>.web.app`. Sem as chaves e o `firebase use`,
o deploy não roda — é só isso que falta.

## Segurança

- Escrita de `subscriptions`, `payments`, `redemptions` bloqueada nas rules — só backend.
- `role` nunca é auto-atribuída pelo cliente (rules + claim).
- Chaves Stripe/Pix só no `.env` das functions, nunca no app/admin.
