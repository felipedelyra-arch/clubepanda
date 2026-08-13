import { useEffect, useMemo, useState } from "react";
import { doc, setDoc } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import {
  UserPlus,
  UserMinus,
  AlertTriangle,
  Check,
  Phone,
  MessageCircle,
  MapPin,
  FileText,
} from "lucide-react";
import { toast } from "sonner";
import { db, functions } from "../lib/firebase";
import { useCollection, useDoc } from "../lib/useCollection";
import type { AppUser, Restaurante } from "../lib/types";
import {
  Card,
  Button,
  Badge,
  Avatar,
  Spinner,
  PageHeader,
  SectionTitle,
} from "../components/ui";
import { Field, inputBase, ConfirmDialog } from "../components/Modal";
import { demoBlock } from "../lib/demo";

const vazio: Restaurante = {
  nome: "",
  telefone: "",
  whatsapp: "",
  endereco: "",
  cidade: "",
  politicaPrivacidadeUrl: "",
  termosUrl: "",
  playStoreUrl: "",
  appStoreUrl: "",
};

type Chave = keyof Restaurante;

interface CampoCfg {
  chave: Chave;
  label: string;
  hint: string;
  placeholder: string;
  /** Valor de exemplo herdado de `app/lib/core/restaurante.dart`. Enquanto o
   *  campo estiver assim, o botão do app abre um número/endereço fictício. */
  exemplo?: string;
  numerico?: boolean;
}

const contato: CampoCfg[] = [
  {
    chave: "nome",
    label: "Nome do restaurante",
    hint: "Aparece no topo do app e nos avisos.",
    placeholder: "Tio Panda",
  },
  {
    chave: "telefone",
    label: "Telefone",
    hint: "Botão Ligar. DDI + DDD + número, só dígitos.",
    placeholder: "551430000000",
    exemplo: "551430000000",
    numerico: true,
  },
  {
    chave: "whatsapp",
    label: "WhatsApp",
    hint: "Botão Falar no WhatsApp. DDI + DDD + número, só dígitos.",
    placeholder: "5514990000000",
    exemplo: "5514990000000",
    numerico: true,
  },
  {
    chave: "endereco",
    label: "Endereço",
    hint: "Botão Como chegar — é o texto que vai pra busca do Google Maps.",
    placeholder: "Rua X, 123 — Bauru/SP",
    exemplo: "Tio Panda restaurante",
  },
  {
    chave: "cidade",
    label: "Cidade",
    hint: "Vai no código Pix da gorjeta — o padrão do Banco Central exige, e corta em 15 letras sem acento.",
    placeholder: "Bauru",
    exemplo: "Bauru",
  },
];

const documentos: CampoCfg[] = [
  {
    chave: "politicaPrivacidadeUrl",
    label: "Política de privacidade",
    hint: "Exigida pela Play Store e pela App Store.",
    placeholder: "https://…",
    exemplo: "https://tiopanda.com.br/privacidade",
  },
  {
    chave: "termosUrl",
    label: "Termos de uso",
    hint: "Link aberto pelo rodapé das configurações do app.",
    placeholder: "https://…",
    exemplo: "https://tiopanda.com.br/termos",
  },
  {
    chave: "playStoreUrl",
    label: "Link na Play Store",
    hint: 'Usado no "Indique um amigo" para quem tem Android.',
    placeholder: "https://play.google.com/…",
    exemplo: "https://play.google.com/store/apps/details?id=com.tiopanda.clube",
  },
  {
    chave: "appStoreUrl",
    label: "Link na App Store",
    hint: 'Usado no "Indique um amigo" para quem tem iPhone.',
    placeholder: "https://apps.apple.com/…",
    exemplo: "https://apps.apple.com/app/id000000000",
  },
];

const todosCampos = [...contato, ...documentos];

const soDigitos = (s: string) => s.replace(/\D/g, "");

/** +55 (14) 99911-0001 — pra conferir de bate-pronto se o número está certo. */
function telefoneBonito(v: string): string | null {
  const s = soDigitos(v);
  if (s.length < 12) return null;
  const [ddi, ddd, resto] = [s.slice(0, 2), s.slice(2, 4), s.slice(4)];
  const corte = resto.length > 8 ? 5 : 4;
  return `+${ddi} (${ddd}) ${resto.slice(0, corte)}-${resto.slice(corte)}`;
}

export function Settings() {
  const { data: users } = useCollection<AppUser>("users");
  const { data: salvo, loading } = useDoc<Restaurante>("config/restaurante");
  const [form, setForm] = useState<Restaurante>(vazio);
  const [salvando, setSalvando] = useState(false);
  const [uidAlvo, setUidAlvo] = useState("");
  const [revogar, setRevogar] = useState<AppUser | null>(null);

  // Preenche o formulário quando o doc chega (e a cada mudança no Firestore).
  useEffect(() => {
    if (salvo) setForm({ ...vazio, ...salvo });
  }, [salvo]);

  const admins = users.filter((u) => u.role === "admin");

  const pendentes = useMemo(
    () =>
      todosCampos.filter((c) => {
        const v = String(form[c.chave] ?? "").trim();
        return !v || (c.exemplo && v === c.exemplo);
      }),
    [form]
  );

  const alterados = useMemo(() => {
    const base = { ...vazio, ...(salvo ?? {}) };
    return todosCampos.filter(
      (c) => String(form[c.chave] ?? "") !== String(base[c.chave] ?? "")
    );
  }, [form, salvo]);

  const set = (campo: Chave) => (e: { target: { value: string } }) =>
    setForm((f) => ({ ...f, [campo]: e.target.value }));

  async function salvarRestaurante() {
    if (!form.nome.trim()) return toast.error("Informe o nome do restaurante.");
    if (form.telefone && soDigitos(form.telefone).length < 12)
      return toast.error("Telefone precisa do DDI + DDD + número (ex.: 551430000000).");
    if (form.whatsapp && soDigitos(form.whatsapp).length < 12)
      return toast.error("WhatsApp precisa do DDI + DDD + número (ex.: 5514990000000).");

    if (demoBlock("Dados não salvos")) return;
    setSalvando(true);
    try {
      await setDoc(
        doc(db, "config", "restaurante"),
        { ...form, telefone: soDigitos(form.telefone), whatsapp: soDigitos(form.whatsapp) },
        { merge: true }
      );
      toast.success("Dados salvos. O app pega a mudança na hora.");
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setSalvando(false);
    }
  }

  async function alterarAdmin(targetUid: string, makeAdmin: boolean) {
    if (demoBlock(makeAdmin ? "Admin não concedido" : "Admin não revogado")) return setUidAlvo("");
    try {
      await httpsCallable(functions, "setAdminRole")({ targetUid, makeAdmin });
      toast.success(makeAdmin ? "Acesso concedido." : "Acesso revogado.");
      setUidAlvo("");
    } catch (e) {
      toast.error((e as Error).message);
    }
  }

  if (loading) return <Spinner />;

  return (
    // pb extra: a barra de "não salvo" flutua sobre o fim da página.
    <div className="max-w-3xl pb-24">
      <PageHeader
        titulo="Configurações"
        eyebrow="Dados do restaurante"
        descricao="É daqui que o app tira o telefone, o endereço e os links que ele mostra pro cliente."
      />

      {/* Checklist: em vez de "3 campos com valor de exemplo", diz quais. Sem o
          nome do campo, o aviso não indica o que fazer. */}
      {pendentes.length > 0 ? (
        <div className="mb-6 rounded-2xl border border-marca/30 bg-marca/8 p-4">
          <div className="flex items-center gap-2 font-semibold text-marca-tinta">
            <AlertTriangle size={17} className="shrink-0" />
            {pendentes.length === 1
              ? "1 campo ainda não é o de verdade"
              : `${pendentes.length} campos ainda não são os de verdade`}
          </div>
          <p className="mt-1 text-sm text-tinta-2">
            Enquanto estiverem assim, os botões do app levam o cliente a um
            número, endereço ou link fictício.
          </p>
          <ul className="mt-3 flex flex-wrap gap-1.5">
            {pendentes.map((c) => (
              <li key={c.chave}>
                <Badge color="orange">{c.label}</Badge>
              </li>
            ))}
          </ul>
        </div>
      ) : (
        <div className="mb-6 flex items-center gap-2 rounded-2xl border border-ok/30 bg-ok/8 p-4 text-sm font-semibold text-ok-tinta">
          <Check size={17} className="shrink-0" />
          Tudo preenchido com dados reais.
        </div>
      )}

      <section className="mb-6">
        <SectionTitle>Contato e localização</SectionTitle>
        <Card>
          <div className="grid gap-x-4 sm:grid-cols-2">
            {contato.map((c) => (
              <div key={c.chave} className={c.chave === "endereco" ? "sm:col-span-2" : ""}>
                <Field label={c.label} hint={c.hint}>
                  <input
                    className={inputBase}
                    value={String(form[c.chave] ?? "")}
                    onChange={set(c.chave)}
                    placeholder={c.placeholder}
                    inputMode={c.numerico ? "numeric" : undefined}
                  />
                  <Confere campo={c} valor={String(form[c.chave] ?? "")} />
                </Field>
              </div>
            ))}
          </div>
        </Card>
      </section>

      <section className="mb-6">
        <SectionTitle>Documentos e lojas</SectionTitle>
        <Card>
          <div className="grid gap-x-4 sm:grid-cols-2">
            {documentos.map((c) => (
              <Field key={c.chave} label={c.label} hint={c.hint}>
                <input
                  className={inputBase}
                  value={String(form[c.chave] ?? "")}
                  onChange={set(c.chave)}
                  placeholder={c.placeholder}
                />
                <Confere campo={c} valor={String(form[c.chave] ?? "")} />
              </Field>
            ))}
          </div>
        </Card>
      </section>

      <section className="mb-6">
        <SectionTitle>Versão mínima do app</SectionTitle>
        <VersaoMinima />
      </section>

      <section>
        <SectionTitle>Quem entra no painel</SectionTitle>
        <Card>
          <p className="mb-4 text-sm text-tinta-2">
            Só quem está nesta lista consegue abrir o painel. O primeiro admin é
            criado por script (ver <code className="font-mono text-xs">firebase/README.md</code>);
            daí em diante é por aqui.
          </p>

          <ul className="mb-4 divide-y divide-linha rounded-2xl border border-linha">
            {admins.map((a) => (
              <li key={a.uid} className="flex items-center gap-3 px-3.5 py-3">
                <Avatar nome={a.nome || a.email} />
                <div className="min-w-0 flex-1">
                  <div className="truncate text-sm font-semibold">{a.nome || a.email}</div>
                  <div className="truncate font-mono text-xs text-tinta-3">{a.uid}</div>
                </div>
                <Badge color="orange">admin</Badge>
                <Button
                  variant="ghost"
                  size="sm"
                  aria-label={`Revogar acesso de ${a.nome || a.email}`}
                  onClick={() => setRevogar(a)}
                >
                  <UserMinus size={16} />
                </Button>
              </li>
            ))}
            {admins.length === 0 && (
              <li className="px-3.5 py-4 text-sm text-tinta-3">
                Nenhum administrador no cadastro.
              </li>
            )}
          </ul>

          <Field
            label="Dar acesso a mais alguém"
            hint="Cole o identificador (UID) da conta. Ele aparece na ficha do membro."
          >
            <div className="flex flex-col gap-2 sm:flex-row">
              <input
                className={inputBase}
                placeholder="Ex.: 8fK2p…"
                value={uidAlvo}
                onChange={(e) => setUidAlvo(e.target.value)}
              />
              <Button onClick={() => alterarAdmin(uidAlvo.trim(), true)} disabled={!uidAlvo.trim()}>
                <UserPlus size={17} /> Conceder
              </Button>
            </div>
          </Field>
        </Card>
      </section>

      <section>
        <SectionTitle>Carteirinhas dos sócios</SectionTitle>
        <CodigosSocio />
      </section>

      {/* Barra de não salvo: aparece só quando há o que salvar, e conta quantos
          campos mudaram. Sem ela, o botão de salvar ficava perdido no meio da
          página e dava pra sair sem gravar. */}
      {alterados.length > 0 && (
        <div className="fixed inset-x-0 bottom-0 z-30 border-t border-linha bg-superficie/95 px-4 py-3 backdrop-blur md:left-[15.5rem]">
          <div className="mx-auto flex max-w-3xl flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
            <span className="text-sm text-tinta-2">
              {alterados.length === 1
                ? "1 campo alterado e ainda não salvo."
                : `${alterados.length} campos alterados e ainda não salvos.`}
            </span>
            <div className="flex gap-2">
              <Button variant="ghost" onClick={() => setForm({ ...vazio, ...(salvo ?? {}) })}>
                Descartar
              </Button>
              <Button onClick={salvarRestaurante} disabled={salvando}>
                {salvando ? "Salvando..." : "Salvar alterações"}
              </Button>
            </div>
          </div>
        </div>
      )}

      <ConfirmDialog
        open={!!revogar}
        onClose={() => setRevogar(null)}
        onConfirm={() => revogar && alterarAdmin(revogar.uid, false)}
        title="Tirar o acesso ao painel?"
        message={`${revogar?.nome || revogar?.email} deixa de conseguir abrir o painel. A conta no app continua normal.`}
        confirmLabel="Tirar acesso"
      />
    </div>
  );
}

/**
 * Gera o código de carteirinha de quem se cadastrou antes dele existir.
 *
 * Conta nova já nasce com código (`functions/src/users.ts`). Quem entrou antes
 * fica sem, e a carteirinha cai no identificador longo — que o atendente não
 * digita quando o leitor de QR falha. Este botão é o conserto, e some da tela
 * quando não há mais ninguém pendente.
 */
function CodigosSocio() {
  const { data: users, loading } = useCollection<AppUser>("users");
  const [rodando, setRodando] = useState(false);

  const pendentes = useMemo(() => users.filter((u) => !u.codigoSocio).length, [users]);

  async function gerar() {
    if (demoBlock("Códigos não gerados")) return;
    setRodando(true);
    try {
      const res = await httpsCallable(functions, "backfillCodigosSocio")({});
      const { gerados, falhas } = res.data as { gerados: number; falhas: string[] };
      if (falhas.length) {
        toast.warning(`${gerados} código(s) gerado(s), ${falhas.length} falhou/falharam.`);
      } else {
        toast.success(
          gerados === 0 ? "Todo mundo já tinha código." : `${gerados} carteirinha(s) prontas.`
        );
      }
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setRodando(false);
    }
  }

  if (loading) return <Spinner />;

  return (
    <Card>
      <p className="mb-4 text-sm text-tinta-2">
        O código curto da carteirinha é o que o atendente lê (ou digita) pra
        identificar o sócio no salão. Conta nova já nasce com ele.
        {pendentes > 0 ? (
          <>
            {" "}
            <strong className="font-semibold text-tinta">
              {pendentes === 1
                ? "1 sócio ainda está sem código"
                : `${pendentes} sócios ainda estão sem código`}
            </strong>{" "}
            — são os que se cadastraram antes.
          </>
        ) : (
          " Ninguém está pendente."
        )}
      </p>

      <Button onClick={gerar} disabled={rodando || pendentes === 0}>
        {rodando ? "Gerando…" : "Gerar códigos que faltam"}
      </Button>
    </Card>
  );
}

/**
 * Trava de versão (`config/app` → `minBuild`). O app lê esse número no boot e
 * bloqueia quem está abaixo dele com a tela de "atualização necessária"
 * (`app/lib/core/version_gate.dart`). É o botão de emergência pra quando uma
 * versão antiga quebra — por isso fica separado do resto, com confirmação.
 */
function VersaoMinima() {
  const { data, loading } = useDoc<{ minBuild?: number }>("config/app");
  const [valor, setValor] = useState("");
  const [salvando, setSalvando] = useState(false);
  const [confirmar, setConfirmar] = useState(false);

  const atual = data?.minBuild ?? null;

  useEffect(() => {
    setValor(atual == null ? "" : String(atual));
  }, [atual]);

  const numero = Number(valor);
  const valido = valor.trim() !== "" && Number.isInteger(numero) && numero >= 0;
  const mudou = valido && numero !== (atual ?? -1);

  async function salvar() {
    if (demoBlock("Versão mínima não alterada")) return;
    setSalvando(true);
    try {
      await setDoc(doc(db, "config", "app"), { minBuild: numero }, { merge: true });
      toast.success(
        numero === 0
          ? "Trava desligada. Todo mundo consegue usar o app."
          : `Trava em ${numero}. Quem está abaixo disso vê a tela de atualizar.`
      );
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setSalvando(false);
    }
  }

  if (loading) return <Spinner />;

  return (
    <Card>
      <p className="mb-4 text-sm text-tinta-2">
        Número da versão (build) mais antiga que ainda pode usar o app. Quem
        estiver abaixo dele fica preso na tela de atualizar até baixar a nova.
        Use <strong className="font-semibold text-tinta">0</strong> pra não
        exigir nada.
      </p>

      <div className="flex flex-col gap-3 sm:flex-row sm:items-end">
        <Field label="Build mínima exigida" hint="Só número inteiro. Ex.: 12.">
          <input
            className={inputBase}
            value={valor}
            onChange={(e) => setValor(e.target.value.replace(/\D/g, ""))}
            inputMode="numeric"
            placeholder="0"
          />
        </Field>
        <div className="mb-4">
          <Button onClick={() => setConfirmar(true)} disabled={!mudou || salvando}>
            {salvando ? "Salvando..." : "Aplicar"}
          </Button>
        </div>
      </div>

      <p className="text-xs text-tinta-3">
        {atual == null || atual === 0
          ? "Hoje: sem exigência — nenhuma versão é bloqueada."
          : `Hoje: build ${atual}. Quem tem uma anterior já está bloqueado.`}
      </p>

      <ConfirmDialog
        open={confirmar}
        onClose={() => setConfirmar(false)}
        onConfirm={salvar}
        title={numero === 0 ? "Desligar a trava?" : `Exigir a build ${numero}?`}
        message={
          numero === 0
            ? "Nenhuma versão do app fica bloqueada."
            : `Todo cliente com build anterior a ${numero} para de usar o app na hora e só volta depois de atualizar na loja. Confira que a versão nova já está publicada.`
        }
        confirmLabel={numero === 0 ? "Desligar" : "Bloquear versões antigas"}
      />
    </Card>
  );
}

/**
 * Linha de conferência abaixo do campo. Telefone vira número formatado, link
 * vira link clicável, valor de exemplo é apontado pelo nome.
 */
function Confere({ campo, valor }: { campo: CampoCfg; valor: string }) {
  const v = valor.trim();
  if (!v) return null;

  if (campo.exemplo && v === campo.exemplo) {
    return (
      <span className="mt-1.5 block text-xs font-semibold text-marca-tinta">
        Ainda é o valor de exemplo.
      </span>
    );
  }

  if (campo.numerico) {
    const bonito = telefoneBonito(v);
    const Icone = campo.chave === "whatsapp" ? MessageCircle : Phone;
    return (
      <span className="mt-1.5 flex items-center gap-1.5 text-xs text-tinta-3">
        <Icone size={12} />
        {bonito ?? "Faltam dígitos — precisa de DDI + DDD + número."}
      </span>
    );
  }

  if (v.startsWith("http")) {
    return (
      <a
        href={v}
        target="_blank"
        rel="noreferrer"
        className="mt-1.5 flex items-center gap-1.5 text-xs text-tinta-3 hover:text-marca-tinta hover:underline"
      >
        <FileText size={12} /> Abrir e conferir
      </a>
    );
  }

  if (campo.chave === "endereco") {
    return (
      <a
        href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(v)}`}
        target="_blank"
        rel="noreferrer"
        className="mt-1.5 flex items-center gap-1.5 text-xs text-tinta-3 hover:text-marca-tinta hover:underline"
      >
        <MapPin size={12} /> Ver no mapa como o cliente vê
      </a>
    );
  }

  return null;
}
