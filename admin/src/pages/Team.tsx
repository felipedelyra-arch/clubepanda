import { useState } from "react";
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  serverTimestamp,
  updateDoc,
} from "firebase/firestore";
import { Plus, Pencil, Trash2, AlertTriangle, ShieldCheck } from "lucide-react";
import { toast } from "sonner";
import { db } from "../lib/firebase";
import { useCollection } from "../lib/useCollection";
import type { Funcionario } from "../lib/types";
import {
  Card,
  Button,
  Badge,
  Spinner,
  EmptyState,
  ErrorState,
  PageHeader,
  Switch,
} from "../components/ui";
import { Modal, ConfirmDialog, Field, inputBase } from "../components/Modal";
import { demoBlock } from "../lib/demo";

const vazio: Partial<Funcionario> = {
  nome: "",
  chavePix: "",
  funcao: "",
  ativo: true,
};

/** Formato de chave aleatória do Pix (UUID v4). */
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type Diagnostico = {
  tipo: "ok" | "aviso" | "bloqueio";
  texto: string;
} | null;

/**
 * Classifica a chave digitada.
 *
 * CPF e telefone são **bloqueados**: a chave fica legível pra qualquer sócio
 * logado (é o que faz a gorjeta funcionar), então salvar um desses publica o
 * documento ou o número pessoal do funcionário pra clientela inteira. Antes
 * isto era só um aviso em vermelho e salvava do mesmo jeito; a auditoria de
 * 15/08 mostrou que ninguém estava protegido de fato.
 *
 * E-mail e CNPJ continuam passando com aviso: expõem menos, e às vezes são o
 * único Pix que a pessoa tem.
 */
function diagnosticar(chave: string): Diagnostico {
  const v = chave.trim();
  if (!v) return null;
  if (UUID.test(v)) {
    return { tipo: "ok", texto: "Chave aleatória — é a recomendada aqui." };
  }
  if (v.includes("@")) {
    return {
      tipo: "aviso",
      texto: "É um e-mail. Todo sócio que resgatar prêmio vai vê-lo.",
    };
  }
  const digitos = v.replace(/\D/g, "");
  if (digitos.length === 11 && digitos === v.replace(/[.\-\s]/g, "")) {
    return {
      tipo: "bloqueio",
      texto:
        "Parece CPF ou telefone. Isso expõe um dado pessoal do funcionário " +
        "pra todos os clientes — peça uma chave aleatória no app do banco.",
    };
  }
  if (digitos.length === 14) {
    return { tipo: "aviso", texto: "Parece CNPJ — confirme se é da pessoa." };
  }
  if (digitos.length >= 12 && digitos.length <= 13) {
    return {
      tipo: "bloqueio",
      texto:
        "Parece telefone. Fica visível pros clientes — peça uma chave " +
        "aleatória no app do banco.",
    };
  }
  return null;
}

export function Team() {
  const { data, loading, error } = useCollection<Funcionario>("funcionarios");
  const [editando, setEditando] = useState<Partial<Funcionario> | null>(null);
  const [excluir, setExcluir] = useState<Funcionario | null>(null);

  const diag = diagnosticar(editando?.chavePix ?? "");

  async function salvar() {
    if (!editando?.nome?.trim()) return toast.error("Informe o nome.");
    if (!editando?.chavePix?.trim()) return toast.error("Informe a chave Pix.");
    // Chave que é dado pessoal não passa: ela fica visível pra todo sócio.
    if (diag?.tipo === "bloqueio") return toast.error(diag.texto);
    if (demoBlock("Funcionário não salvo")) return setEditando(null);

    const payload = {
      nome: editando.nome.trim(),
      chavePix: editando.chavePix.trim(),
      funcao: editando.funcao?.trim() ?? "",
      ativo: editando.ativo ?? true,
    };
    try {
      if (editando.id) {
        await updateDoc(doc(db, "funcionarios", editando.id), payload);
      } else {
        await addDoc(collection(db, "funcionarios"), {
          ...payload,
          criadoEm: serverTimestamp(),
        });
      }
      toast.success("Funcionário salvo.");
      setEditando(null);
    } catch (e) {
      toast.error((e as Error).message);
    }
  }

  async function alternarAtivo(f: Funcionario) {
    if (demoBlock("Nada alterado")) return;
    try {
      await updateDoc(doc(db, "funcionarios", f.id), { ativo: !f.ativo });
    } catch (e) {
      toast.error((e as Error).message);
    }
  }

  if (loading) return <Spinner />;
  if (error) return <ErrorState mensagem={error} />;

  return (
    <div>
      <PageHeader
        titulo="Equipe"
        descricao="Quem aparece na lista de gorjeta do app. O cliente escolhe o nome depois de resgatar um prêmio e paga por Pix direto pra pessoa — o restaurante não recebe nem repassa esse valor."
        acao={
          <Button onClick={() => setEditando({ ...vazio })}>
            <Plus size={18} /> Adicionar
          </Button>
        }
      />

      <Card className="mb-4 border-l-4 border-l-panda-laranja">
        <div className="flex gap-3">
          <AlertTriangle size={18} className="mt-0.5 shrink-0 text-panda-laranja" />
          <div className="text-sm text-tinta-2">
            <p className="font-semibold text-tinta">
              Use chave aleatória, nunca CPF ou telefone.
            </p>
            <p className="mt-1">
              A chave cadastrada aqui fica visível pra qualquer sócio que
              resgatar um prêmio. Chave aleatória é gratuita, ilimitada, pode ser
              apagada quando a pessoa sai, e não revela nada sobre ela — é criada
              no app do banco, em Pix &rarr; Minhas chaves.
            </p>
            <p className="mt-1">
              Confira a chave com o próprio funcionário na hora de cadastrar:
              chave errada manda o dinheiro pra um estranho, sem volta.
            </p>
          </div>
        </div>
      </Card>

      {data.length === 0 ? (
        <EmptyState
          mensagem="Ninguém cadastrado — o convite de gorjeta não aparece no app enquanto essa lista estiver vazia."
          acao={
            <Button onClick={() => setEditando({ ...vazio })}>
              <Plus size={18} /> Adicionar alguém
            </Button>
          }
        />
      ) : (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {data.map((f) => {
            const d = diagnosticar(f.chavePix);
            return (
              <Card key={f.id}>
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <h3 className="truncate font-semibold">{f.nome}</h3>
                    {f.funcao && (
                      <p className="text-sm text-tinta-3">{f.funcao}</p>
                    )}
                  </div>
                  <Badge color={f.ativo ? "green" : "gray"}>
                    {f.ativo ? "No app" : "Fora"}
                  </Badge>
                </div>

                <p className="mt-3 truncate font-mono text-xs text-tinta-3" title={f.chavePix}>
                  {f.chavePix}
                </p>
                {/* Cadastro antigo pode ter chave que hoje não passaria mais:
                    a trava vale na hora de salvar, não apaga o que já existe. */}
                {(d?.tipo === "aviso" || d?.tipo === "bloqueio") && (
                  <p className="mt-1 flex gap-1 text-xs text-panda-vermelho">
                    <AlertTriangle size={13} className="mt-0.5 shrink-0" />
                    {d.texto}
                  </p>
                )}

                <div className="mt-4 flex items-center gap-2">
                  <Switch
                    checked={f.ativo}
                    onChange={() => alternarAtivo(f)}
                    label="Aparece no app"
                  />
                  <div className="flex-1" />
                  <Button variant="outline" onClick={() => setEditando(f)}>
                    <Pencil size={16} />
                  </Button>
                  <Button variant="ghost" onClick={() => setExcluir(f)}>
                    <Trash2 size={16} className="text-panda-vermelho" />
                  </Button>
                </div>
              </Card>
            );
          })}
        </div>
      )}

      <Modal
        open={!!editando}
        onClose={() => setEditando(null)}
        title={editando?.id ? "Editar funcionário" : "Novo funcionário"}
      >
        {editando && (
          <>
            <Field label="Nome">
              <input
                className={inputBase}
                value={editando.nome ?? ""}
                onChange={(e) => setEditando({ ...editando, nome: e.target.value })}
                placeholder="Como o cliente vai reconhecer a pessoa"
              />
            </Field>
            <Field label="Função (opcional)">
              <input
                className={inputBase}
                value={editando.funcao ?? ""}
                onChange={(e) => setEditando({ ...editando, funcao: e.target.value })}
                placeholder="Garçom, Sushiman…"
              />
            </Field>
            <Field label="Chave Pix">
              <input
                className={inputBase}
                value={editando.chavePix ?? ""}
                onChange={(e) => setEditando({ ...editando, chavePix: e.target.value })}
                placeholder="7b3e1c9a-4d52-4f8b-9c21-6a0e5d7f2b18"
              />
            </Field>
            {diag && (
              <p
                className={`-mt-2 mb-3 flex gap-1.5 text-xs ${
                  diag.tipo === "ok" ? "text-panda-verde" : "text-panda-vermelho"
                }`}
              >
                {diag.tipo === "ok" ? (
                  <ShieldCheck size={14} className="mt-0.5 shrink-0" />
                ) : (
                  <AlertTriangle size={14} className="mt-0.5 shrink-0" />
                )}
                {diag.texto}
              </p>
            )}
            <div className="mb-3">
              <Switch
                checked={editando.ativo ?? true}
                onChange={(v) => setEditando({ ...editando, ativo: v })}
                label="Aparece na lista de gorjeta do app"
              />
            </div>
            {/* Desabilitado já diz que não vai passar, sem precisar tentar.
                `salvar()` recusa de novo por baixo — a trava é lá, não aqui. */}
            <Button
              onClick={salvar}
              disabled={diag?.tipo === "bloqueio"}
              className="mt-1 w-full"
            >
              Salvar
            </Button>
          </>
        )}
      </Modal>

      <ConfirmDialog
        open={!!excluir}
        onClose={() => setExcluir(null)}
        onConfirm={async () => {
          if (demoBlock("Nada excluído")) return;
          if (excluir) {
            await deleteDoc(doc(db, "funcionarios", excluir.id));
            toast.success("Funcionário removido.");
          }
        }}
        title="Remover funcionário?"
        message={`"${excluir?.nome}" sai da lista de gorjeta do app. Se a pessoa só saiu de férias, use o botão de desligar em vez de remover.`}
      />
    </div>
  );
}
