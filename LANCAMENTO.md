# Lançamento na Play Store e na App Store

Checklist de tudo que falta pra publicar. O que está marcado ✅ já está no código;
o resto é conta, chave ou arquivo que só o dono do restaurante consegue criar.

> Ordem sugerida: **1 → 2 → 3** antes de qualquer coisa. Sem o Firebase real, o app
> compila mas não conecta em nada, e não adianta testar mais nada.

---

## 1. Firebase de verdade (bloqueia todo o resto)

Hoje `app/lib/firebase_options.dart` é um **placeholder** com chaves fictícias, e não
existem `google-services.json` (Android) nem `GoogleService-Info.plist` (iOS).

```bash
dart pub global activate flutterfire_cli
cd app
flutterfire configure --project=clube-panda
```

Isso reescreve `firebase_options.dart` com as chaves reais e cria os dois arquivos
nativos. O `android/app/build.gradle.kts` **liga sozinho** os plugins do Google
Services e do Crashlytics assim que o `google-services.json` aparecer. ✅

No console do Firebase, ainda: habilitar **Authentication** (e-mail/senha, Google,
Apple), **Firestore**, **Storage** e **Cloud Messaging**.

## 2. Backend no ar

```bash
cd firebase
firebase login && firebase use --add
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

- A function `publicarPromocoesAgendadas` é agendada — o deploy vai pedir o
  **Cloud Scheduler** habilitado no projeto (exige plano Blaze).
- Segredos das Functions: `STRIPE_SECRET_KEY` e `STRIPE_WEBHOOK_SECRET`.
- Criar o primeiro admin pelo script em `firebase/README.md`. Daí em diante é pelo
  painel (Configurações → Quem entra no painel).

## 3. Preencher os dados do restaurante **pelo painel**

Configurações → Dados do restaurante. O app lê o doc `config/restaurante` em tempo
real ✅ — trocar o telefone no painel muda o app na hora, sem publicar versão nova.

Falta preencher com o que é real: telefone, WhatsApp, endereço, política de
privacidade, termos, e os links das duas lojas (depois que o app for publicado).

**A política de privacidade precisa estar numa URL pública** — as duas lojas exigem, e
a ficha da loja pede o mesmo link.

---

## 4. Android — o que já está pronto e o que falta

> ⚠️ **Esta máquina ainda não tem o Android SDK** (`flutter doctor` → *Unable to locate
> Android SDK*). Sem ele não sai APK nem AAB. Instale o
> [Android Studio](https://developer.android.com/studio) e deixe ele baixar o SDK na
> primeira abertura. Enquanto isso, as mudanças de Gradle e de manifesto abaixo estão
> escritas mas **nunca foram compiladas**.


| Item | Status |
|---|---|
| `applicationId` `com.tiopanda.clube_panda` | ✅ |
| Nome no launcher: "Clube Panda" | ✅ |
| Ícone gerado da logo (inclusive adaptativo) | ✅ `dart run flutter_launcher_icons` |
| Permissões `INTERNET` e `POST_NOTIFICATIONS` | ✅ |
| `<queries>` de `tel:`/`https:` (senão os botões de contato não abrem no Android 11+) | ✅ |
| Símbolos nativos no bundle (`SYMBOL_TABLE`) | ✅ |
| **Keystore de upload** | ❌ só você |

Sem keystore o release sai assinado com a chave de **debug** e a Play Store recusa.

```bash
keytool -genkey -v -keystore %USERPROFILE%\clubepanda-upload.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Depois copie `app/android/key.properties.example` para `app/android/key.properties` e
preencha. O Gradle passa a assinar de verdade sozinho. **Guarde o `.jks` e as senhas
com a sua vida**: perder essa chave significa nunca mais poder atualizar o app
publicado. Nenhum dos dois entra no git.

Gerar o pacote de envio:

```bash
cd app && flutter build appbundle --release
# saída: build/app/outputs/bundle/release/app-release.aab
```

## 5. iOS — o que já está pronto e o que falta

| Item | Status |
|---|---|
| Bundle id `com.tiopanda.clubePanda`, nome "Clube Panda" | ✅ |
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
