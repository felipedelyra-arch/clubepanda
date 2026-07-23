import { useState } from "react";
import { addDoc, collection, deleteDoc, doc, updateDoc } from "firebase/firestore";
import { Plus, Pencil, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { db } from "../lib/firebase";
import { useCollection } from "../lib/useCollection";
import type { Plan } from "../lib/types";
import { Card, Button, Badge, Spinner, EmptyState } from "../components/ui";
import { Modal, ConfirmDialog, Field, inputBase } from "../components/Modal";

const intervalos = ["mensal", "trimestral", "anual"] as const;
const vazio: Partial<Plan> = { nome: "", preco: 0, intervalo: "mensal", beneficios: [], recomendado: false };

export function Plans() {
  const { data, loading } = useCollection<Plan>("plans");
  const [editando, setEditando] = useState<Partial<Plan> | null>(null);
  const [excluir, setExcluir] = useState<Plan | null>(null);
  const [beneficiosStr, setBeneficiosStr] = useState("");

  function abrir(p?: Plan) {
    setEditando(p ?? { ...vazio });
    setBeneficiosStr((p?.beneficios ?? []).join("\n"));
  }

  async function salvar() {
    if (!editando?.nome) return toast.error("Informe o nome.");
    const payload = {
      nome: editando.nome,
      preco: Number(editando.preco ?? 0),
      intervalo: editando.intervalo ?? "mensal",
      beneficios: beneficiosStr.split("\n").map((s) => s.trim()).filter(Boolean),
      recomendado: editando.recomendado ?? false,
      stripePriceId: editando.stripePriceId ?? null,
    };
    try {
      if (editando.id) await updateDoc(doc(db, "plans", editando.id), payload);
      else await addDoc(collection(db, "plans"), payload);
      toast.success("Plano salvo.");
      setEditando(null);
    } catch (e) {
      toast.error((e as Error).message);
    }
  }

  if (loading) return <Spinner />;
  const brl = (v: number) => v.toLocaleString("pt-BR", { style: "currency", currency: "BRL" });

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold">Planos</h1>
        <Button onClick={() => abrir()}><Plus size={18} /> Novo plano</Button>
      </div>

      {data.length === 0 ? (
        <EmptyState mensagem="Nenhum plano cadastrado." />
      ) : (
        <div className="grid gap-4 md:grid-cols-3">
          {data.map((p) => (
            <Card key={p.id} className={p.recomendado ? "ring-2 ring-panda-laranja" : ""}>
              <div className="flex items-center justify-between">
                <h3 className="font-semibold">{p.nome}</h3>
                {p.recomendado && <Badge color="orange">Recomendado</Badge>}
              </div>
              <div className="mt-2 text-2xl font-bold text-panda-laranja">
                {brl(p.preco)} <span className="text-sm font-normal text-panda-cinza-texto">/ {p.intervalo}</span>
              </div>
              <ul className="mt-3 space-y-1 text-sm text-panda-cinza-texto">
                {p.beneficios?.map((b, i) => <li key={i}>• {b}</li>)}
              </ul>
              {!p.stripePriceId && <p className="mt-2 text-xs text-panda-vermelho">Sem stripePriceId — assinatura por cartão não funciona.</p>}
              <div className="mt-4 flex gap-2">
                <Button variant="outline" className="flex-1" onClick={() => abrir(p)}><Pencil size={16} /> Editar</Button>
                <Button variant="ghost" onClick={() => setExcluir(p)}><Trash2 size={16} className="text-panda-vermelho" /></Button>
              </div>
            </Card>
          ))}
        </div>
      )}

      <Modal open={!!editando} onClose={() => setEditando(null)} title={editando?.id ? "Editar plano" : "Novo plano"}>
        {editando && (
          <>
            <Field label="Nome"><input className={inputBase} value={editando.nome ?? ""} onChange={(e) => setEditando({ ...editando, nome: e.target.value })} /></Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="Preço (R$)"><input type="number" step="0.01" className={inputBase} value={editando.preco ?? 0} onChange={(e) => setEditando({ ...editando, preco: Number(e.target.value) })} /></Field>
              <Field label="Intervalo">
                <select className={inputBase} value={editando.intervalo ?? "mensal"} onChange={(e) => setEditando({ ...editando, intervalo: e.target.value as Plan["intervalo"] })}>
                  {intervalos.map((i) => <option key={i} value={i}>{i}</option>)}
                </select>
              </Field>
            </div>
            <Field label="Benefícios (um por linha)"><textarea className={inputBase} rows={4} value={beneficiosStr} onChange={(e) => setBeneficiosStr(e.target.value)} /></Field>
            <Field label="Stripe Price ID"><input className={inputBase} placeholder="price_..." value={editando.stripePriceId ?? ""} onChange={(e) => setEditando({ ...editando, stripePriceId: e.target.value })} /></Field>
            <label className="mb-4 flex items-center gap-2 text-sm">
              <input type="checkbox" checked={editando.recomendado ?? false} onChange={(e) => setEditando({ ...editando, recomendado: e.target.checked })} />
              Plano recomendado
            </label>
            <Button onClick={salvar} className="w-full">Salvar</Button>
          </>
        )}
      </Modal>

      <ConfirmDialog open={!!excluir} onClose={() => setExcluir(null)}
        onConfirm={async () => { if (excluir) { await deleteDoc(doc(db, "plans", excluir.id)); toast.success("Plano excluído."); } }}
        title="Excluir plano?" message={`"${excluir?.nome}" será removido.`} />
    </div>
  );
}
