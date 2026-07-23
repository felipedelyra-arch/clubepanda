# Clube Panda — Painel do Admin (React)

Painel web onde o dono do Tio Panda administra o clube. Mesmo backend Firebase do app.

## Stack

- React 19 + TypeScript + Vite
- **UI:** Tailwind CSS v4 (paleta Tio Panda, dark mode)
- **Rotas:** react-router-dom (guarda de admin)
- **Gráficos:** Recharts · **Toasts:** sonner · **Ícones:** lucide-react
- **Backend:** Firebase (Auth, Firestore, Functions `southamerica-east1`, Storage)

## Setup

```bash
npm install
cp .env.example .env    # preencha com as chaves do SEU projeto Firebase (Web app)
npm run dev             # http://localhost:5173
```

Login exige conta com custom claim `role:admin`. Crie o primeiro admin pelo
script em `firebase/scripts/set-first-admin.js`; depois gerencie em Configurações.

## Telas

| Rota | Tela | Função |
|---|---|---|
| `/login` | Login | e-mail/senha; bloqueia não-admin ("Acesso negado"); recuperar senha |
| `/` | Dashboard | membros ativos, novos/mês, MRR, cancelamentos, resgates + 2 gráficos |
| `/promocoes` | Promoções | CRUD + upload de imagem (Storage) + ativa/só-assinantes |
| `/premiacoes` | Premiações | CRUD + estoque/pontos + validar resgates (QR/código) |
| `/planos` | Planos | CRUD + `stripePriceId` para checkout recorrente |
| `/membros` | Membros | tabela + busca + ajustar pontos |
| `/pagamentos` | Financeiro | transações, filtro por método, exportar CSV, total |
| `/notificacoes` | Notificações | enviar push (todos ou só assinantes) via Cloud Function |
| `/configuracoes` | Config | dados do restaurante + conceder/revogar admin |

## Tempo real

Todas as telas assinam o Firestore (`onSnapshot`). Promoção criada aqui aparece
**na hora** no app do cliente — mesmo banco.

## Segurança

- Guarda de rota: sem sessão **ou** sem claim `admin` → redireciona pro login.
- Ações sensíveis (push, validar resgate, conceder admin) chamam Cloud Functions,
  nunca escrevem direto. Chaves Stripe/Pix ficam só no backend.
- Exclusões pedem confirmação em modal.

## Deploy

```bash
npm run build
firebase deploy --only hosting     # ou: vercel deploy
```
