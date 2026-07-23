import { useState } from "react";
import { addDoc, collection, deleteDoc, doc, updateDoc } from "firebase/firestore";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
import { httpsCallable } from "firebase/functions";
import { Plus, Pencil, Trash2, CheckCircle } from "lucide-react";
import { toast } from "sonner";
import { db, storage, functions } from "../lib/firebase";
import { useCollection } from "../lib/useCollection";
import type { Reward, Redemption, RewardTipo } from "../lib/types";
import { Card, Button, Badge, Spinner, EmptyState } from "../components/ui";
import { Modal, ConfirmDialog, Field, inputBase } from "../components/Modal";

const tipos: RewardTipo[] = ["rodizio", "prato", "sobremesa", "cupom"];
const vazio: Partial<Reward> = { titulo: "", descricao: "", tipo: "cupom", custoPontos: 0, estoque: 1, apenasAssinantes: false };

export function Rewards() {
  const { data, loading } = useCollection<Reward>("rewards");
  const { data: redemptions } = useCollection<Redemption>("redemptions");
  const [editando, setEditando] = useState<Partial<Reward> | null>(null);
  const [excluir, setExcluir] = useState<Reward | null>(null);
  const [arquivo, setArquivo] = useState<File | null>(null);
  const [salvando, setSalvando] = useState(false);

  async function salvar() {
    if (!editando?.titulo) return toast.error("Informe o título.");
    setSalvando(true);
    try {
      let imagem = editando.imagem ?? null;
      if (arquivo) {
        const r = ref(storage, `rewards/${Date.now()}_${arquivo.name}`);
        await uploadBytes(r, arquivo);
        imagem = await getDownloadURL(r);
      }
      const payload = {
        titulo: editando.titulo,
        descricao: editando.descricao ?? "",
        tipo: editando.tipo ?? "cupom",
        custoPontos: Number(editando.custoPontos ?? 0),
        estoque: Number(editando.estoque ?? 0),
        apenasAssinantes: editando.apenasAssinantes ?? false,
        imagem,
      };
      if (editando.id) await updateDoc(doc(db, "rewards", editando.id), payload);
      else await addDoc(collection(db, "rewards"), payload);
      toast.success("Premiação salva.");
      setEditando(null);
      setArquivo(null);
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setSalvando(false);
    }
  }

  async function validar(codigo: string) {
    try {
      await httpsCallable(functions, "validateRedemption")({ codigo });
      toast.success("Resgate validado.");
    } catch (e) {
      toast.error((e as Error).message);
    }
  }

  if (loading) return <Spinner />;

  const pendentes = redemptions.filter((r) => r.status === "disponivel");

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold">Premiações</h1>
        <Button onClick={() => setEditando({ ...vazio })}>
          <Plus size={18} /> Nova premiação
        </Button>
      </div>

      {data.length === 0 ? (
        <EmptyState mensagem="Nenhuma premiação cadastrada." />
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {data.map((r) => (
            <Card key={r.id}>
              <div className="flex items-start justify-between gap-2">
                <h3 className="font-semibold">{r.titulo}</h3>
                <Badge color={r.estoque > 0 ? "green" : "red"}>Estoque {r.estoque}</Badge>
              </div>
              <p className="mt-1 text-sm text-panda-cinza-texto">{r.descricao}</p>
              <div className="mt-2 flex flex-wrap gap-2">
                <Badge color="gray">{r.tipo}</Badge>
                {r.apenasAssinantes ? <Badge color="orange">Exclusivo</Badge> : <Badge color="orange">{r.custoPontos} pts</Badge>}
              </div>
              <div className="mt-4 flex gap-2">
                <Button variant="outline" className="flex-1" onClick={() => setEditando(r)}>
                  <Pencil size={16} /> Editar
                </Button>
                <Button variant="ghost" onClick={() => setExcluir(r)}>
                  <Trash2 size={16} className="text-panda-vermelho" />
                </Button>
              </div>
            </Card>
          ))}
        </div>
      )}

      <h2 className="mt-10 mb-4 text-lg font-bold">Resgates pendentes de validação</h2>
      {pendentes.length === 0 ? (
        <EmptyState mensagem="Nenhum resgate aguardando validação." />
      ) : (
        <Card className="p-0 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-black/5 dark:bg-white/5 text-left text-panda-cinza-texto">
              <tr>
                <th className="p-3">Prêmio</th>
                <th className="p-3">Código</th>
                <th className="p-3"></th>
              </tr>
            </thead>
            <tbody>
              {pendentes.map((r) => (
                <tr key={r.id} className="border-t border-black/5 dark:border-white/5">
                  <td className="p-3">{r.rewardTitulo}</td>
                  <td className="p-3 font-mono">{r.codigo}</td>
                  <td className="p-3 text-right">
                    <Button variant="outline" onClick={() => validar(r.codigo)}>
                      <CheckCircle size={16} /> Validar
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      )}

      <Modal open={!!editando} onClose={() => setEditando(null)} title={editando?.id ? "Editar premiação" : "Nova premiação"}>
        {editando && (
          <>
            <Field label="Título">
              <input className={inputBase} value={editando.titulo ?? ""} onChange={(e) => setEditando({ ...editando, titulo: e.target.value })} />
            </Field>
            <Field label="Descrição">
              <textarea className={inputBase} rows={2} value={editando.descricao ?? ""} onChange={(e) => setEditando({ ...editando, descricao: e.target.value })} />
            </Field>
            <Field label="Tipo">
              <select className={inputBase} value={editando.tipo ?? "cupom"} onChange={(e) => setEditando({ ...editando, tipo: e.target.value as RewardTipo })}>
                {tipos.map((t) => <option key={t} value={t}>{t}</option>)}
              </select>
            </Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="Custo (pontos)">
                <input type="number" className={inputBase} value={editando.custoPontos ?? 0} onChange={(e) => setEditando({ ...editando, custoPontos: Number(e.target.value) })} />
              </Field>
              <Field label="Estoque">
                <input type="number" className={inputBase} value={editando.estoque ?? 0} onChange={(e) => setEditando({ ...editando, estoque: Number(e.target.value) })} />
              </Field>
            </div>
            <Field label="Imagem">
              <input type="file" accept="image/*" onChange={(e) => setArquivo(e.target.files?.[0] ?? null)} />
            </Field>
            <label className="mb-4 flex items-center gap-2 text-sm">
              <input type="checkbox" checked={editando.apenasAssinantes ?? false} onChange={(e) => setEditando({ ...editando, apenasAssinantes: e.target.checked })} />
              Exclusivo para assinantes
            </label>
            <Button onClick={salvar} disabled={salvando} className="w-full">
              {salvando ? "Salvando..." : "Salvar"}
            </Button>
          </>
        )}
      </Modal>

      <ConfirmDialog
        open={!!excluir}
        onClose={() => setExcluir(null)}
        onConfirm={async () => {
          if (excluir) {
            await deleteDoc(doc(db, "rewards", excluir.id));
            toast.success("Premiação excluída.");
          }
        }}
        title="Excluir premiação?"
        message={`"${excluir?.titulo}" será removida.`}
      />
    </div>
  );
}
