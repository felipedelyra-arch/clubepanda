# PandaVip — Tio Panda 🐼🍣

Clube de assinatura do restaurante japonês **Tio Panda**. Cliente paga mensalidade e ganha
promoções e premiações (rodízios, pratos, sobremesas, brindes, cupons) lançadas pelo dono.

## Arquitetura

Monorepo com **um backend Firebase** compartilhado por duas aplicações:

| Pasta | O quê | Stack |
|---|---|---|
| `firebase/` | Backend único | Firestore, Auth, Cloud Functions (TS), Storage, Cloud Messaging |
| `app/` | App do Cliente (iOS/Android/Web) | Flutter + Riverpod + go_router |
| `admin/` | Painel do Admin (web) | React + TypeScript + Vite + Tailwind |

Painel e app conversam pelo **mesmo Firestore em tempo real**.

---

## 🚀 Rodar o app pra testar (modo demo — login de teste)

O app tem um **modo demo** que **não precisa de Firebase nem internet**: usa dados fictícios
e um login de teste já preenchido. É a forma mais fácil de rodar na máquina de qualquer
pessoa pra avaliar o app.

**Pré-requisito:** [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado
(`flutter doctor` sem erros) e o Chrome.

```bash
cd app
flutter pub get
flutter run -d chrome --dart-define=DEMO=true
```

- **Login de teste:** já vem preenchido → e-mail `cliente@teste.com`, senha `123456`.
  (No modo demo qualquer e-mail/senha entra — é só clicar **Entrar**.)
- Na **primeira vez** aparece o tour de boas-vindas (onboarding).
- Tudo funciona offline: carteirinha, cardápio, prêmios, notificações, perfil.

> Rodar em **navegador** (`-d chrome`) mostra o app dentro de uma moldura de celular.
> Rodar em **celular/emulador** (`-d <device>`) mostra em tela cheia.

Pra ver os dispositivos disponíveis: `flutter devices`.

---

## 📱 Funções do app (cliente)

| Tela | O que faz |
|---|---|
| **Onboarding** | Tour de 3 passos na primeira abertura (carteirinha, pontos, notificações). Aparece só uma vez — guardado em `shared_preferences`. |
| **Login / Cadastro** | Entrar por e-mail/senha. Cadastro coleta nome, e-mail, telefone (WhatsApp), **data de aniversário** e senha. |
| **Home** | Saudação, status de sócio, **sino de notificações** (com contador de não lidas), atalho da carteirinha, destaques do cardápio (fotos), promoções, "como funciona" e contatos (ligar / WhatsApp / como chegar). |
| **Carteirinha digital** | QR Code do sócio pra mostrar no caixa e juntar pontos. |
| **Cardápio** | Categorias e pratos com foto e preço. |
| **Prêmios** | Saldo de pontos e catálogo de recompensas (rodízio, sushi, sobremesa, cupom) pra trocar. |
| **Planos** | Assinatura atual, benefícios e gerenciamento (plano único R$ 4,90/mês). |
| **Notificações** | Central de avisos e promoções, com ícone por tipo (promo / aniversário / info) e horário relativo. Respeita a preferência de ligar/desligar. |
| **Perfil** | Dados do sócio, cupons resgatados, dados da conta (incl. aniversário) e **Acessibilidade**. |

### Acessibilidade & preferências (persistidas em `shared_preferences`)

- **Tamanho da letra** (A− / A+): escala o texto de todo o app (Normal → Máximo). Mantém a
  escolha entre sessões.
- **Receber notificações** (liga/desliga): quando desligado, a central mostra estado
  "desligado" e o sino some. Padrão: ligado.

### Aniversário

Coletado no cadastro (seletor de data em pt-BR) e salvo no perfil (`nascimento`). Base pra
enviar o mimo de aniversário e a notificação "Feliz aniversário 🎂".

### Notificações push (FCM)

Fora do modo demo, o app registra o token FCM no doc do usuário ao logar
(`core/services/push_service.dart`). O envio de push sai das Cloud Functions.

---

## Ordem de execução (roadmap)

1. **Firebase** — projeto, Auth, Firestore + coleções, Storage, Security Rules. ✅ base
2. **Cloud Functions** — custom claim `role:admin`, webhooks pagamento (Stripe + Pix),
   criar/sincronizar assinatura, conceder admin, enviar push. ✅ base
3. **App Flutter** — design system → auth (com aniversário) → onboarding → home → premiações
   → assinatura → notificações → perfil (acessibilidade) → push.
4. **Admin React** — auth+guarda admin → layout → dashboard → promoções → premiações →
   planos → membros → pagamentos → notificações → config.

## Modelo de dados (Firestore)

`users`, `subscriptions`, `plans`, `promotions`, `rewards`, `redemptions`, `payments`,
`users/{uid}/notifications`.
Detalhe em [`firebase/firestore.rules`](firebase/firestore.rules) e nos READMEs de cada projeto.

Campos novos em `users`: `nascimento` (Timestamp, opcional), `fcmToken`.

## Segurança (regra de ouro)

Cobrança, criação de assinatura, concessão de admin, envio de push e validação de pagamento
rodam **apenas em Cloud Functions**. Cliente nunca escreve isso direto.

## Setup completo (com backend real)

```bash
# 1. Backend
cd firebase && npm --prefix functions install
firebase login && firebase use --add          # selecione seu projeto
firebase deploy --only firestore:rules,storage,functions

# 2. Admin
cd ../admin && npm install && npm run dev

# 3. App (requer Flutter SDK instalado)
cd ../app && flutter pub get && flutter run   # sem --dart-define usa o Firebase real
```

Variáveis de ambiente: copie cada `.env.example` para `.env` e preencha.

## Identidade visual

Paleta laranja Tio Panda (`#E86A22`), preto panda quente (`#201B15`), tema claro/escuro.
Design system compartilhado em código nas duas apps.
