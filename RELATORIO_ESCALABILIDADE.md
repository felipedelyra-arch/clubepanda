# PandaVip — Relatório de Escalabilidade e Resiliência

**Fase 1 (diagnóstico) e Onda 1 (ganhos rápidos) — concluídas.**
Data: 15/08/2026 · Commit base do diagnóstico: `11df0cd`

> **Estado:** a Onda 1 foi executada. Os resultados estão na seção 10, no fim.
> As seções 1 a 9 são o diagnóstico original, mantido como estava para servir
> de linha de base — o que foi corrigido depois está marcado ao lado.

---

## 1. Resumo para leigo

O PandaVip hoje aguenta com folga o restaurante inteiro do Tio Panda em número
de **cadastros** — alguns milhares de sócios não incomodam nada. O problema não
é quantidade de gente cadastrada, é **gente fazendo a mesma coisa no mesmo
segundo**.

O primeiro componente a quebrar é o **resgate de prêmio**. Todo resgate do mesmo
prêmio passa pelo mesmo registro no banco, e o banco atende esse registro em
fila, um de cada vez. Enquanto os resgates chegam espaçados, ninguém percebe.
Mas o app manda uma notificação quando o dono cadastra um prêmio — e aí todo
mundo abre o celular junto e toca "resgatar" junto. Na medição, **25 pessoas
simultâneas já derrubaram 44% dos resgates** e 50 simultâneas derrubaram 92%,
com a mensagem "Não foi possível resgatar" na tela de quem tentou.

O segundo a quebrar é o **envio da notificação para assinantes**: ele busca os
assinantes de 30 em 30, um pedido de cada vez. Com 2.500 assinantes já consome
68% do tempo máximo que a função tem para rodar antes de ser cortada.

O terceiro é o **painel do dono**, que carrega coleções inteiras sem limite —
17.531 documentos por abertura no cenário medido, e isso cresce para sempre
porque cada conta fechada no salão vira um documento novo.

Nada disso está no ar ainda: as Cloud Functions exigem o plano Blaze e não foram
publicadas. Ou seja, **dá para corrigir tudo antes de o primeiro cliente
encostar** — que é a hora mais barata possível.

---

## 2. Como isto foi medido (e o que os números valem)

Este projeto não tem servidor próprio. Não existe pool de conexões, ORM,
`EXPLAIN`, instância para saturar nem WebSocket. Rodar k6 contra o emulador
mediria a velocidade do emulador Java rodando neste notebook, e o número não
teria relação nenhuma com o Firestore de produção.

Por isso a medição foi feita em duas moedas diferentes, com confiabilidade
diferente — e a distinção importa:

| Tipo de número | Confiança | Por quê |
|---|---|---|
| **Contagem de operações** (leituras, escritas, idas ao banco) | **Alta.** Vale para produção sem ajuste. | É determinada pelo código, não pelo hardware. `users.get()` lê N documentos aqui e lá. |
| **Tempo absoluto** (ms) | **Baixa.** Só serve para comparar entre si. | O emulador é um processo Java local; o Firestore real é distribuído e muito mais rápido por operação. |
| **Formato da curva** (linear? quadrático? serializado?) | **Alta.** | O gargalo é número de idas sequenciais ao banco, e isso não muda de ambiente. |

**Ambiente:** emulador Firestore v1.22.0 + Auth + Functions, Java 21, Node 24,
5.000 usuários / 2.500 assinaturas / 10.000 contas de salão semeados.
Scripts em `loadtest/` (`seed.js`, `medir-push.js`, `medir-resgate.js`,
`medir-painel.js`, `medir-app.js`).

> **Correção a um registro anterior:** a nota de sessão dizia que o emulador não
> rodava por exigir JDK 21 numa máquina com Java 8. Está desatualizada — a
> máquina tem OpenJDK 21.0.12 e o emulador subiu normalmente.

---

## 3. Resultados medidos

### 3.1 Contagem de operações (confiável)

| Ação | Leituras | Escritas | Idas ao banco **sequenciais** |
|---|---:|---:|---:|
| Push "todos" (5.000 pessoas) | 5.000 | 5.000 | 13 |
| Push "assinantes" (2.500) | **5.000** | 2.500 | **85** |
| Abrir painel — Dashboard | **17.531** | 0 | 6 |
| Abrir painel — Membros | 17.529 | 0 | 5 |
| Abrir app — sócio com 12 avisos | 19 | 0 | 9 |
| Abrir app — sócio com 300 avisos | **307** | 0 | 9 |

Dois destaques:

- O push para **assinantes lê o dobro** do que precisa (5.000 leituras para
  alcançar 2.500 pessoas): ele lê a coleção de assinaturas inteira e depois
  relê os usuários correspondentes, de 30 em 30.
- Abrir o app custa **19 leituras** com histórico curto e **307** com histórico
  de 300 avisos. Cada push que o dono manda soma +1 permanentemente, para cada
  sócio, para sempre.

### 3.2 Corrida pelo mesmo prêmio (formato da curva)

Todas as pessoas resgatando o mesmo prêmio, transação idêntica à de
`redemptions.ts:31`:

| Simultâneos | Sucesso | Falha | Erro |
|---:|---:|---:|---|
| 10 | 10/10 (100%) | 0% | — |
| 25 | 14/25 (56%) | **44%** | `ABORTED: Transaction lock timeout` |
| 50 | 4/50 (8%) | **92%** | `ABORTED: Transaction lock timeout` |

O estoque **nunca ficou negativo** nem divergiu (baixou exatamente o número de
resgates gravados). A transação está correta — ela apenas não escala, porque
serializa no documento do prêmio.

> **Ressalva honesta:** o emulador é mais pessimista que o Firestore real em
> contenção. Em produção esses percentuais serão melhores. O que **não** muda é
> o mecanismo: o Firestore sustenta cerca de **1 escrita por segundo por
> documento**, e aqui todos os resgates de um prêmio disputam um documento só.
> O ponto de quebra é mais alto em produção; ele continua existindo, e continua
> sendo dezenas–centenas de pessoas, não milhares.

### 3.3 Custo projetado (Firestore, leitura a US$ 0,06/100 mil)

Abrir o app, 2 vezes por dia, 30 dias:

| Sócios | Com histórico curto (19 leituras) | Com 300 avisos (307 leituras) |
|---:|---|---|
| 1.000 | R$ 3,69/mês | R$ 59,68/mês |
| 10.000 | R$ 36,94/mês | **R$ 596,81/mês** |
| 50.000 | R$ 184,68/mês | **R$ 2.984,04/mês** |

Painel do dono, 20 aberturas por dia, no cenário medido (5.000 sócios /
10.000 contas): **R$ 34,08/mês só para olhar o Dashboard** — e esse número
cresce todo mês, porque `payments` nunca para de crescer.

> **Ressalva:** o Firestore reaproveita cache local e retoma listeners com
> token, então nem toda abertura relê tudo. A coluna de 307 leituras é o **pior
> caso** (abertura fria depois de horas fora), não a média. A ressalva não
> muda a conclusão: o número cresce sem teto, e colocar `limit` resolve a
> dúvida inteira.

---

## 4. Tabela de gargalos

Severidade: **P0** = quebra na cara do cliente · **P1** = quebra ao crescer ·
**P2** = custo/manutenção.

| # | Problema | Arquivo:linha | Impacto | Esforço | Risco de mexer |
|---|---|---|---|---|---|
| 1 | Todos os resgates do mesmo prêmio serializam num documento. Push de prêmio novo cria avalanche exatamente nesse ponto. | `firebase/functions/src/redemptions.ts:31-81` | **P0** — 44% de falha a 25 simultâneos | **G** | **Médio** — mexe na garantia de estoque; exige teste de integridade |
| 2 | Push para assinantes faz 1 + N/30 consultas **sequenciais**; lê 2× o necessário. | `firebase/functions/src/push.ts:30-42` | **P1** — 68% do timeout com 2.500 assinantes | **P** | Baixo |
| 3 | Painel carrega coleções inteiras, sem `limit` nem `where`, em listener vivo. | `admin/src/lib/useCollection.ts:43` + `pages/Dashboard.tsx:248-253`, `Members.tsx:18-22`, `Payments.tsx:48-49` | **P1** — 17,5 mil documentos/abertura, cresce para sempre; trava o navegador | **M** | Baixo |
| 4 | `notifications` e `redemptions` do app sem `limit`. | `app/lib/core/services/services.dart:173`, `:193` | **P1** — custo por sócio cresce sem teto | **P** | Baixo |
| 5 | `backfillCodigosSocio` varre `users` inteiro e roda 1 transação por pessoa, sequencial. | `firebase/functions/src/users.ts:50-63` | **P1** — estoura o timeout de 60s por volta de 500–1.000 pendentes | **P** | Baixo |
| 6 | Escrita de 1 documento de aviso por pessoa, para sempre, sem expurgo. | `firebase/functions/src/push.ts:52-70` | **P1** — é a causa raiz do #4 | **M** | Baixo |
| 7 | ~~`maxInstances: 10` global, aplicado inclusive ao webhook do PDV.~~ **RETIRADO — eu errei, ver abaixo** | `firebase/functions/src/index.ts:7` | não é gargalo | — | — |
| 8 | `deleteAccount` apaga com um único `batch()` (limite de 500 documentos). | `firebase/functions/src/account.ts:33-41` | **P2** — falha em sócio com +500 resgates/assinaturas | **P** | Baixo |
| 9 | `createCheckoutSession` sem trava de concorrência: 2 toques rápidos podem criar 2 clientes no Stripe. | `firebase/functions/src/subscriptions.ts:29-38` | **P2** — sujeira no Stripe | **P** | Baixo |
| 10 | Coleções compartilhadas (`rewards`, `plans`, `menu`) lidas inteiras por cada app aberto. | `app/lib/core/services/services.dart:70,80,145` | **P2** — hoje é pequeno; vira custo com cardápio grande | **P** | Baixo |

#### Correção ao item 7 (`maxInstances`)

Listei isso como P1 dizendo que era "teto rígido de concorrência para tudo".
Está errado em duas frentes, e a conclusão se inverte:

1. No Cloud Functions **de 2ª geração cada função tem o próprio conjunto de
   instâncias**. `maxInstances: 10` em `setGlobalOptions` vale **por função**,
   não é uma cota compartilhada. O webhook do PDV não disputa instância com o
   resgate do app.
2. As funções quase não entram no caminho quente. Abrir o app, ver oferta, ver
   cardápio e ver carteirinha falam direto com o Firestore. Função só é
   chamada em evento raro: resgatar, assinar, cancelar, excluir conta, aplicar
   indicação.

E há um detalhe que torna mexer aqui **contraproducente**: o gargalo real do
resgate é a disputa pelo documento do prêmio (item 1). Enquanto isso não for
resolvido, um teto baixo de instâncias funciona como freio — segura a
avalanche antes que ela vire transação abortada na cara do cliente. Subir o
teto agora pioraria o sintoma.

**Decisão: não mexer.** Reavaliar depois do item 1 da Onda 2, junto com o
alerta de orçamento.

### O que **não** é problema (verificado, para não gastar esforço à toa)

- **Idempotência de escrita já existe** onde importa: consumo de salão por id
  determinístico de comanda (`lib/consumo.ts:89` + `create()` em `:211`) e
  fatura do Stripe (`webhooks/stripe.ts:65`). Isso é melhor do que a maioria
  dos projetos nesta fase.
- **Índices:** as consultas do app e das functions são só de igualdade, ou já
  têm índice composto declarado em `firestore.indexes.json`. Não achei consulta
  sem índice.
- **Upload de mídia já vai direto ao Storage** (`profile_screen.dart:237`), não
  passa por função nenhuma.
- **Webhooks assinados** com HMAC de corpo cru e `timingSafeEqual`
  (`webhooks/pdv.ts:33-40`), e o PDV recebe 200 em caso de duplicata para não
  entrar em laço de reenvio (`webhooks/pdv.ts:49`).
- **Regras do Firestore** são lista branca de campos, com negação no fim.

---

## 5. Diagnóstico de resiliência (queda de rede e sessão)

Boa notícia primeiro: **o Firebase já entrega de graça a maior parte da Fase 3
do seu prompt.** Vale entender exatamente o quê, para não reconstruir o que já
funciona.

### Já resolvido pelo SDK, sem código nosso

| Cenário | O que acontece hoje | Por quê |
|---|---|---|
| App abre sem internet | Mostra os dados da última vez, não fica em branco | Cache offline do Firestore é **ligado por padrão** no Android/iOS |
| Escrita direta no Firestore com rede caída (editar perfil, marcar aviso como lido, salvar token de push) | Entra na fila em disco do SDK, sobrevive a fechar o app e reiniciar o celular, sobe sozinha quando a rede volta | Fila de escrita nativa do Firestore |
| Token de acesso expira durante o uso | Renova sozinho, em silêncio | `firebase_auth` renova internamente; o app nunca vê 401 |
| 10 requisições recebem 401 juntas | Um refresh só, as demais esperam | O SDK já faz *single-flight*; não há refresh manual no código |
| App volta do background depois de horas | Listeners reconectam e sincronizam o delta | Retomada por token de resumo do Firestore |
| Deslogar por erro transitório | **Não acontece.** `sair()` (`auth_perfil.dart:100`) só é chamado por ação explícita do usuário e depois de excluir a conta | Verificado nos 4 pontos de chamada |

Há também cuidado já escrito à mão que merece registro: `perfilCompletoProvider`
(`auth_perfil.dart:143`) trata erro de leitura como "não sei" em vez de
"incompleto" — sem isso, ficar offline jogaria o sócio no formulário de cadastro
toda vez que abrisse o app.

### O buraco real: as chamadas de Cloud Function

Chamada de função **não tem fila offline**. Nenhuma. Se a rede cair no meio,
some. São 6 pontos:

| Chamada | Arquivo:linha | O que o usuário perde |
|---|---|---|
| `redeemReward` | `rewards_screen.dart:415` | **O mais grave.** Ver abaixo. |
| `createCheckoutSession` | `plans_screen.dart:112` | Não assina; toca de novo e resolve |
| `cancelSubscription` | `plans_screen.dart:604` | Não cancela; toca de novo |
| `deleteAccount` | `settings_screen.dart:766` | Exclusão pela metade (ver abaixo) |
| `applyReferral` | `signup_screen.dart:131` | Código de indicação não aplicado, **silenciosamente** (`catch (_)` em `:133`) |
| `ensureReferralCode` | `profile_screen.dart:574` | Tela de indicação sem código |

**O caso do resgate, em detalhe.** A rede cai depois de a função gravar o resgate
e antes de a resposta chegar ao celular. O app mostra "Não foi possível
resgatar". A pessoa toca de novo e recebe **"Você já resgatou este prêmio"** —
uma mensagem de erro para uma operação que deu certo. O prêmio não se perde de
verdade (o resgate aparece na lista via `redemptionsProvider`), mas a experiência
diz o contrário, e o código do QR não é mostrado na tela onde ela estava.
Falta uma `Idempotency-Key` gerada no cliente: com ela, a repetição devolveria o
mesmo resgate e o mesmo QR em vez de um erro.

**O caso da exclusão de conta.** `deleteAccount` (`account.ts:13-68`) executa 6
etapas sem transação: cancela no Stripe → apaga assinaturas → apaga resgates →
apaga índices reversos → apaga o perfil → apaga do Auth. Queda de rede ou timeout
no meio deixa a conta **meio apagada**, e não há retomada. Para exigência de LGPD
e das lojas, é o pior lugar para ficar pela metade.

### Cenários do seu prompt, respondidos

| Cenário | Hoje |
|---|---|
| Modo avião no meio de uma escrita | Escrita direta no Firestore: **sobrevive**. Chamada de função: **perde** |
| Rede cai e volta 5 vezes | Firestore reconecta sozinho. Chamadas de função em curso morrem, sem retentativa |
| App morto pelo sistema com fila cheia | Fila do Firestore sobrevive em disco. Não existe fila para funções |
| Servidor devolve 500 e volta | Firestore repete sozinho. Função: erro na tela, sem *backoff* |
| Existe indicador de conexão? | Sim, `ConnectivityGate` (`core/connectivity.dart:15`) |
| Distingue "sem rede" de "servidor fora"? | **Não.** Só olha a interface de rede — Wi-Fi conectado a um roteador sem internet aparece como online |
| Existe caixa de "não enviados"? | **Não** |
| Retentativa com *backoff* nas funções? | **Não** |

---

## 6. Alvo recomendado

**Perseguir 20.000 sócios. Declarar 1 milhão fora de escopo, explicitamente.**

Justificativa: é um clube de vantagens de **um** restaurante em Bauru. O teto
real não é técnico, é a praça. Projetar para 1 milhão custaria semanas e o
dinheiro do dono para atender um número que não vai existir — e escalar depois
é possível, porque nada nesta stack impede.

Com as correções das Ondas 1 e 2, 20.000 sócios ficam confortáveis e a conta
mensal fica assim (Firestore + Functions, estimativa):

| Sócios | Sem correção | Com Ondas 1 e 2 |
|---:|---|---|
| 1.000 | ~R$ 60/mês | dentro da cota gratuita, ~R$ 0 |
| 10.000 | ~R$ 600/mês | ~R$ 60–90/mês |
| 20.000 | ~R$ 1.200/mês | ~R$ 120–180/mês |

Contra R$ 4,90/mês por sócio, a infraestrutura corrigida fica abaixo de **0,2%
da receita**. Sem correção, passa de 1%.

**Fora de escopo, e por quê:**
- Redis, filas dedicadas, réplica de leitura, Kubernetes, troca de banco: o
  diagnóstico não achou gargalo que exija nada disso. O Firestore já é
  distribuído e o Cloud Functions já escala sozinho.
- Load balancer e auto-scaling: não se aplica — não há instância nossa.
- CDN: o Firebase Hosting já é CDN.

---

## 7. Plano em 3 ondas

### Onda 1 — ganhos rápidos, sem risco (≈ meio dia)

1. `limit(50)` em `notifications` e `redemptions` no app, com "ver mais".
   Resolve o gargalo #4 e derruba o custo por sócio de 307 para ~20 leituras.
2. Trocar a busca de assinantes de 30 em 30 por leitura direta por id
   (`getAll`) ou por um campo `assinante` no próprio `users`. Resolve #2:
   85 idas ao banco viram 1–2.
3. `limit` + paginação nas listas do painel, começando por `payments` e `users`.
   Resolve #3.
4. `backfillCodigosSocio` passa a processar em lotes com cursor e a devolver
   "continua". Resolve #5.
5. `deleteAccount` com laço de lotes de 500. Resolve #8.
6. Subir `maxInstances` e separar o webhook do PDV num teto próprio, com alerta
   de orçamento. Resolve #7.

### Onda 2 — estrutural (≈ 2–3 dias)

7. **Tirar o resgate da disputa por um documento.** Resolve #1 — é a mudança que
   importa. Duas saídas possíveis, a decidir com medição:
   - *contador distribuído* (o estoque vira N sub-documentos e o resgate sorteia
     um); ou
   - *cupons pré-gerados* (o dono cadastra 200 prêmios como 200 documentos e o
     resgate reserva um livre — sem contenção nenhuma, e é o desenho que combina
     com "cada pessoa resgata uma vez").
8. **`Idempotency-Key` nas chamadas de função de escrita**, gerada no cliente e
   guardada no servidor: repetir devolve a mesma resposta.
9. **Fila persistente no app** apenas para as chamadas de função, com *backoff*
   exponencial + *jitter*, e caixa visível de "não enviados". O Firestore já
   cuida do resto — não duplicar o que o SDK faz.
10. **`deleteAccount` retomável**, marcando etapa concluída, para não deixar
    conta meio apagada.
11. **Expurgo de avisos antigos** (`onSchedule`), atacando a causa raiz de #6.
12. Distinguir "sem rede" de "servidor fora" no `ConnectivityGate`.

### Onda 3 — infraestrutura (propor, não executar)

13. Alerta de orçamento no Blaze antes de qualquer outra coisa.
14. Painel de métricas: invocações, erro, duração p95, leituras/dia por coleção.
15. Alertas com limiar concreto (ex.: leituras/dia acima de 2× a média de 7 dias).
16. App Check com imposição ligada, um produto por vez.

---

## 8. Riscos que continuam abertos

- **Nada disso está no ar.** As 7 funções exigem Blaze. Enquanto não subir, o
  resgate — o produto — não funciona em produção, e nenhuma correção de
  escalabilidade é observável de verdade.
- Números de tempo são de emulador. As **contagens** valem; os **milissegundos**
  não. Só teste em produção com Blaze fecha isso.
- A regra de `users` virou lista branca em `11df0cd` e **nunca rodou em
  runtime**. Agora que o emulador funciona nesta máquina, dá para testar — e
  isso deveria vir antes de qualquer mudança desta lista.

---

## 9. Próximo passo recomendado

Antes da Onda 1, gastar 30 minutos rodando o cadastro e a edição de perfil
contra o emulador para validar a regra de `users` do commit `11df0cd`. É a única
mudança já commitada capaz de travar o app em produção, e agora é barato
verificar.

Depois disso, Onda 1 inteira num dia — são seis correções pequenas, todas de
risco baixo, e derrubam o custo projetado em 10×.

**A Onda 2 (item 7, o resgate) é a que decide se o app sobrevive ao dia em que o
dono cadastrar um rodízio grátis e mandar push para todo mundo.**

---

## 10. Onda 1 — executada (15/08/2026)

### 10.0 A regra de `users` foi validada primeiro

`firebase/test/rules.test.js`, **21 casos, todos passando**. Sete deles copiam
literalmente os campos de cada ponto de escrita do app; o resto cobre o que a
regra existe para barrar. **Veredito: a lista branca do commit `11df0cd` está
completa e correta. Nenhuma correção foi necessária.**

Rodar com `cd firebase/functions && npm run test:rules`, com o emulador do
Firestore no ar. Acrescentar um campo em qualquer tela de perfil sem pôr na
lista passa a quebrar o teste em vez do cliente.

### 10.1 Antes e depois

| O que | Antes | Depois | Fator |
|---|---:|---:|---:|
| Push para 2.500 assinantes — idas ao banco | 85 | 10 | **8,5×** |
| Push para 2.500 assinantes — tempo (emulador) | 40.148 ms | 857 ms | 46,8× |
| Push — orçamento de timeout consumido | 66,9% | 1,4% | — |
| Abrir o app (sócio com 300 avisos) | 303 leituras | 53 | **5,7×** |
| Painel — Dashboard | 18.100 | 19 | **953×** |
| Painel — Configurações | 5.600 | 52 | 108× |
| Painel — Notificações | 8.100 | 103 | 79× |
| Painel — Financeiro | 15.600 | 1.000 | 16× |
| Painel — Membros | 18.101 | 8.101 | 2× |
| **Painel — uma volta por todas as páginas** | **65.501** | **9.276** | **7×** |

Custo projetado, com as mesmas contas do item 3.3:

| | Antes | Depois |
|---|---|---|
| Abertura de app, 10.000 sócios | ~R$ 597/mês | ~R$ 103/mês |
| Painel, 20 voltas por dia | ~R$ 127/mês | ~R$ 18/mês |

> **Leia os fatores, não os milissegundos.** As contagens de leitura e de idas
> ao banco valem para produção — são determinadas pelo código. Os tempos são de
> emulador e só servem para comparar antes e depois na mesma máquina.

### 10.2 O que mudou, item a item

| # | Item | Situação | Commit |
|---|---|---|---|
| 2 | Push para assinantes de 30 em 30, sequencial | **corrigido** — `getAll` por id, em pedaços paralelos | `4f34529` |
| 3 | Painel baixando coleções inteiras | **corrigido** — agregação no servidor, filtro na consulta, ficha sob demanda | `d02172e`, `b20a9ae` |
| 4 | `notifications` sem `limit` | **corrigido** — `limit(50)` | `0c98e5d` |
| 5 | `backfillCodigosSocio` estourando o timeout | **corrigido** — pedaços com cursor, verificado em 600 perfis | `3bb57af` |
| 8 | `deleteAccount` com batch único | **corrigido** — voltas de 450 | `1049e51` |
| 7 | `maxInstances` | **retirado** — eu tinha errado o diagnóstico (ver seção 4) | — |

Correções que apareceram no caminho e não estavam na lista:

- **`_marcarLidas` (app)** montava um batch único com todos os avisos não
  lidos. Sócio com mais de 500 estourava o limite do batch, num `catch`
  silencioso — e tudo continuava não lido para sempre. Agora vai em lotes.
- **Aviso de lista cortada no Financeiro.** Sem ele, os totais da tela
  pareceriam o período inteiro quando são só as mais recentes, e o dono
  fecharia o mês com número menor que a verdade.

### 10.3 Mudança de comportamento assumida

Os cartões e gráficos do **Dashboard deixaram de atualizar sozinhos em tempo
real** — agregação é consulta pontual, não listener. Recarregam ao abrir a
página e num botão "Atualizar" ao lado do título. O bloco "No ar agora"
(ofertas e prêmios) continua ao vivo.

### 10.4 Ainda aberto

- **Item 1, a disputa pelo documento do prêmio — intocado.** É o P0, é Onda 2,
  e é o que decide o dia em que o dono cadastrar um rodízio grátis e mandar
  push. Precisa de decisão de desenho: contador distribuído ou cupons
  pré-gerados.
- **Item 6**, expurgo de avisos antigos: o `limit(50)` tratou o custo de
  leitura, mas a subcoleção continua crescendo para sempre no banco.
- **Membros** ainda carrega `users` e `subscriptions` inteiras. Só 2× de ganho.
  Quando o clube passar de alguns milhares, precisa de busca no servidor
  (campo `nomeBusca` em minúsculas, consulta por prefixo) e paginação. Está
  comentado no arquivo.
- **Item 9**, `createCheckoutSession` sem trava de concorrência: fica com a
  Onda 2, junto do trabalho de idempotência, onde pertence.
- **Índice novo** em `payments` (status ASC, data ASC) precisa subir com
  `firebase deploy --only firestore:indexes` antes do painel ir a produção.
- **Nada disso está no ar.** Continua valendo: sem Blaze, as 7 funções não
  existem em produção.
