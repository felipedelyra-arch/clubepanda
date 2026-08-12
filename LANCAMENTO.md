# Lançamento na Play Store e na App Store

Checklist de tudo que falta pra publicar. O que está marcado ✅ já está no código;
o resto é conta, chave ou arquivo que só o dono do restaurante consegue criar.

> Ordem sugerida: **1 → 2 → 3** antes de qualquer coisa. Sem o Firebase real, o app
> compila mas não conecta em nada, e não adianta testar mais nada.

---

## 1. Firebase de verdade ✅ FEITO

`flutterfire configure --project=pandavip` já rodou. `firebase_options.dart` tem as
chaves reais e o `google-services.json` existe, então o `android/app/build.gradle.kts`
liga sozinho os plugins do Google Services e do Crashlytics. Authentication, Firestore
e Cloud Messaging estão habilitados no console.

**Storage não** — o bucket só pode ser criado depois do Blaze (ver item 2).

### Chaves de API restritas ✅

São **três**, uma por plataforma (`app/lib/firebase_options.dart`). Restringidas em
https://console.cloud.google.com/apis/credentials?project=pandavip:

- **Android** — pacote `com.tiopanda.pandavip` com as **duas** SHA-1 (release e
  debug). Só a de release quebraria o `flutter run` no celular.
- **Web** — 7 sites, todos terminando em `/*`. Inclui
  `https://pandavip.firebaseapp.com/*`, que é por onde passa o redirecionamento do
  login Google/Apple: sem ela o login social falha sem erro claro. Mais `localhost` e
  `127.0.0.1` nas portas 5173 e 8910. **O console recusa curinga em porta** — por isso
  `admin/vite.config.ts` fixa a 5173 com `strictPort`.
- **iOS** — ❌ ainda falta: Aplicativos iOS → `com.tiopanda.pandavip`.

> Quando entrar domínio próprio, o domínio precisa ser adicionado em **duas listas
> diferentes**: a chave Web acima **e** Authentication → Settings → Domínios
> autorizados. Só a primeira não basta.

## 2. Backend no ar — ⚠️ bloqueado no Blaze

Regras já publicadas ✅ (`firestore.rules`, incluindo a coleção `funcionarios`).
Falta o resto, e nada disso sai sem plano Blaze:

```bash
cd firebase
firebase deploy --only functions,storage
```

- **As 7 Functions não estão no ar.** Em produção isso significa que **resgatar
  prêmio não funciona** (`redeemReward`), nem apagar conta, assinar, cancelar ou
  indicar. O app hoje faz login, mostra oferta, cardápio e carteirinha — só.
- `storage.rules` está escrito e pronto, mas o deploy falha com
  `Firebase Storage has not been set up on project 'pandavip'`: o bucket só existe
  depois do Blaze. **A região do bucket é definitiva** — escolher
  `southamerica-east1`, igual às Functions.
- A function `publicarPromocoesAgendadas` é agendada — o deploy vai pedir o
  **Cloud Scheduler** habilitado.
- Segredos das Functions: `STRIPE_SECRET_KEY` e `STRIPE_WEBHOOK_SECRET`.
- Antes de ligar o Blaze, criar alerta de orçamento de R$ 20. Ele **avisa, não
  corta** — não existe teto de gasto no Google Cloud. O que limita de verdade é o
  `maxInstances: 10` em `firebase/functions/src/index.ts`.

## 3. Preencher os dados do restaurante **pelo painel**

Configurações → Dados do restaurante. O app lê o doc `config/restaurante` em tempo
real ✅ — trocar o telefone no painel muda o app na hora, sem publicar versão nova.

Falta preencher com o que é real: telefone, WhatsApp, endereço, **cidade** (o BR Code
do Pix da gorjeta exige), política de privacidade, termos, e os links das duas lojas
(depois que o app for publicado).

### Política de privacidade — escrita, ⚠️ não publicada

Está em `app/web/privacidade.html`. O Flutter copia a pasta `web/` inteira pro build,
então ela sai em `https://pandavip-app.web.app/privacidade.html` e sobrevive a toda
recompilação.

**Não subiu de propósito**: faltam razão social, CNPJ, endereço e e-mail do
restaurante, que estão como `[PLACEHOLDER]` com um aviso no topo do arquivo. Política
no ar com colchete é pior que política nenhuma — é a primeira coisa que o revisor da
Play abre.

### O que só o dono resolve, sem custo

- Os **3 benefícios reais** do plano de R$ 4,90 (o que está lá é texto de exemplo).
- As **chaves Pix da equipe**, cadastradas em Equipe (`/equipe`). Têm que ser chave
  **aleatória**: o sócio que resgata enxerga a chave na tela.
- Os dados legais da política acima.

---

## 4. Android — o que já está pronto e o que falta

> O Android SDK está instalado nesta máquina, no "caminho magro" (sem Android Studio):
> JDK 17 Temurin em `~\Android\jdk`, SDK em `~\Android\Sdk`. `flutter doctor` dá
> **Android toolchain ✓**.

| Item | Status |
|---|---|
| `applicationId` `com.tiopanda.pandavip` | ✅ |
| Nome no launcher: "PandaVip" | ✅ |
| Ícone gerado da logo (inclusive adaptativo) | ✅ `dart run flutter_launcher_icons` |
| Permissões `INTERNET` e `POST_NOTIFICATIONS` | ✅ |
| `<queries>` de `tel:`/`https:` (senão os botões de contato não abrem no Android 11+) | ✅ |
| Símbolos nativos no bundle (`SYMBOL_TABLE`) | ✅ |
| **Keystore de upload** | ✅ feito |

### Keystore ✅

`C:\Users\Usuario\pandavip-upload.jks`, PKCS12, alias `upload`, válido até
**28/12/2053**. Senha em `app/android/key.properties` (fora do git, junto com o
`.jks`).

Verificado com `gradlew :app:signingReport`: `Variant: release` usa
`Config: release` apontando pro `.jks` — antes o release saía assinado com a chave de
**debug**, que a Play recusa.

**SHA-1 de release**, a que vai nas restrições de chave de API e no App Check:

```
2C:2E:E4:1E:D9:13:06:D8:AE:1D:74:1A:17:35:B5:E7:13:8A:9C:25
```

> ⚠️ **Guarde o `.jks` e a senha com a sua vida, fora desta máquina.** Perder essa
> chave depois do app publicado significa nunca mais poder atualizá-lo — nem o Google
> resolve. É o único item deste checklist sem conserto.

Pra gerar de novo (só antes de publicar; depois disso a chave é definitiva):

```bash
keytool -genkeypair -v -keystore %USERPROFILE%\pandavip-upload.jks \
  -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Gerar o pacote de envio:

```bash
cd app && flutter build appbundle --release
# saída: build/app/outputs/bundle/release/app-release.aab
```

## 5. iOS — o que já está pronto e o que falta

| Item | Status |
|---|---|
| Bundle id `com.tiopanda.pandavip`, nome "PandaVip" | ✅ |
| `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription` (sem elas o app **crasha** ao trocar a foto do perfil e a Apple rejeita) | ✅ |
| `UIBackgroundModes: remote-notification` | ✅ |
| `ITSAppUsesNonExemptEncryption = false` (some com a pergunta de exportação a cada envio) | ✅ |
| Ícone 1024 sem transparência | ✅ |
| **Mac com Xcode** (ou serviço de build na nuvem) | ❌ só você |
| **Conta Apple Developer** (US$ 99/ano) | ❌ só você |
| Capability **Push Notifications** + chave **APNs** no Firebase | ❌ no Xcode/console |
| **Sign in with Apple** — obrigatório porque o app tem login com Google | ❌ no Xcode/console |

Não dá pra compilar iOS no Windows. É Mac emprestado/alugado ou serviço de build
na nuvem.

> EAS (`eas init`) é da Expo e só builda React Native — não serve pra Flutter.

## 5b. App Check — SDK instalado, imposição desligada

O App Check prova ao Firebase que a chamada veio do app de verdade, e não de um script
com a chave de API copiada do APK.

- **App Flutter ✅** — `firebase_app_check` ligado em `app/lib/main.dart`, logo depois
  do `Firebase.initializeApp`: `AndroidPlayIntegrityProvider` /
  `AppleAppAttestProvider` em release, provedores de depuração fora dele. **Web fica
  de fora** (`if (!kIsWeb)`) porque lá o provedor é reCAPTCHA e a chave de site ainda
  não existe — chamar `activate` sem ela estoura antes do `runApp` e deixa a página
  branca.
- **Painel ❌** — ainda sem SDK. Usa o pacote `firebase` inteiro, então é só importar
  `firebase/app-check`; falta criar a chave reCAPTCHA no console (grátis, não exige
  Blaze).

> ⚠️ **Não ative a imposição ainda.** Com ela ligada, todo cliente sem SDK de App
> Check é bloqueado — inclusive qualquer APK compilado antes desta mudança.

Ordem certa: SDK instalado (feito no app) → tokens de depuração registrados no console
→ app publicado em teste interno → olhar as métricas de "solicitações verificadas" →
só então impor, **um produto por vez** (Firestore, depois Storage, depois Functions).

Decisões já tomadas no console: TTL **1 hora**, `PLAY_RECOGNIZED` marcado, `LICENSED`
desmarcado, integridade do dispositivo em "Não verificar explicitamente".

## 6. Contas e fichas das lojas

- **Google Play Console** — US$ 25, uma vez. Conta de desenvolvedor pessoa física hoje
  exige teste fechado com testadores antes de liberar produção.
- **Apple Developer Program** — US$ 99/ano.
- Para as duas: ícone, screenshots (vários tamanhos), descrição curta e longa,
  classificação etária, categoria, e-mail de suporte, link da política de privacidade.
- **Questionário de dados**: Data Safety (Google) e App Privacy (Apple). O app coleta
  nome, e-mail, telefone, endereço, data de nascimento e foto — tudo precisa ser
  declarado.
- **Conta de teste pro revisor** (e-mail e senha de um sócio ativo). Sem isso a
  revisão trava na tela de login.

## 7. Pagamento — o ponto de atenção

A Apple exige compra dentro do app (In-App Purchase) para benefício **digital**. Clube
de desconto consumido no salão do restaurante costuma passar com cobrança externa
(Stripe), mas é a rejeição mais comum nesse tipo de app.

Na nota do revisor, diga com todas as letras que **o benefício é resgatado
presencialmente no restaurante**, e não dentro do app.

Falta ainda: chaves do Stripe, criar os preços, apontar o webhook, e pagar a
recompensa do "indique um amigo" no webhook (o gancho existe, ainda não credita).

## 8. Antes de subir cada versão

```bash
cd app
flutter analyze && flutter test
flutter build appbundle --release
```

- Subir o `versionCode`/`versionName` em `pubspec.yaml` (`version: 1.0.0+1`).
- Depois que a versão nova estiver publicada nas lojas, dá pra bloquear as antigas em
  Configurações → **Versão mínima do app** no painel ✅ (o app mostra a tela de
  atualização obrigatória pra quem estiver abaixo do número).

---

## O que já está conectado painel ↔ app

Tudo pelo mesmo Firestore, em tempo real — salvou no painel, aparece no app:

- Promoções (com janela de validade e agendamento), prêmios, cardápio, planos.
- Avisos: o disparo grava na central de avisos de cada cliente e manda o push.
- Dados do restaurante (`config/restaurante`) e trava de versão (`config/app`).
- Do lado do app pro painel: cadastros, assinaturas, resgates e pagamentos.

**Ainda não existe**: integração com o sistema de comanda do salão. Enquanto o PDV não
gravar em `payments`, mesa, atendente e itens consumidos ficam vazios em produção — só
a mensalidade aparece.
