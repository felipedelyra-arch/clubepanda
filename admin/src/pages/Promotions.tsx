import { useState } from "react";
import { addDoc, collection, deleteDoc, doc, updateDoc } from "firebase/firestore";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
import { Plus, Pencil, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { db, storage } from "../lib/firebase";
import { useCollection } from "../lib/useCollection";
import type { Promotion } from "../lib/types";
import { Card, Button, Badge, Spinner, EmptyState } from "../components/ui";
import { Modal, ConfirmDialog, Field, inputBase } from "../components/Modal";
import { demoBlock } from "../lib/demo";

const vazia: Partial<Promotion> = {
  titulo: "",
  descricao: "",
  ativa: true,
  apenasAssinantes: false,
  imagem: null,
};

export function Promotions() {
  const { data, loading } = useCollection<Promotion>("promotions");
  const [editando, setEditando] = useState<Partial<Promotion> | null>(null);
  const [excluir, setExcluir] = useState<Promotion | null>(null);
  const [salvando, setSalvando] = useState(false);
  const [arquivo, setArquivo] = useState<File | null>(null);

  async function salvar() {
    if (!editando?.titulo) return toast.error("Informe o título.");
    if (demoBlock("Promoção não salva")) return setEditando(null);
    setSalvando(true);
    try {
      let imagem = editando.imagem ?? null;
      if (arquivo) {
        const r = ref(storage, `promotions/${Date.now()}_${arquivo.name}`);
        await uploadBytes(r, arquivo);
        imagem = await getDownloadURL(r);
      }
      const payload = {
        titulo: editando.titulo,
        descricao: editando.descricao ?? "",
        ativa: editando.ativa ?? true,
        apenasAssinantes: editando.apenasAssinantes ?? false,
        imagem,
      };
      if (editando.id) {
        await updateDoc(doc(db, "promotions", editando.id), payload);
      } else {
        await addDoc(collection(db, "promotions"), payload);
      }
      toast.success("Promoção salva.");
      setEditando(null);
      setArquivo(null);
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setSalvando(false);
    }
  }

  if (loading) return <Spinner />;

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold">Promoções</h1>
        <Button onClick={() => setEditando({ ...vazia })}>
          <Plus size={18} /> Nova promoção
        </Button>
      </div>

      {data.length === 0 ? (
        <EmptyState mensagem="Nenhuma promoção. Crie a primeira!" />
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {data.map((p) => (
            <Card key={p.id}>
              {p.imagem && (
                <img src={p.imagem} alt="" className="mb-3 h-36 w-full rounded-xl object-cover" />
              )}
              <div className="flex items-start justify-between gap-2">
                <h3 className="font-semibold">{p.titulo}</h3>
                <Badge color={p.ativa ? "green" : "gray"}>{p.ativa ? "Ativa" : "Inativa"}</Badge>
              </div>
              <p className="mt-1 text-sm text-panda-cinza-texto">{p.descricao}</p>
              {p.apenasAssinantes && <div className="mt-2"><Badge color="orange">Só assinantes</Badge></div>}
              <div className="mt-4 flex gap-2">
                <Button variant="outline" className="flex-1" onClick={() => setEditando(p)}>
                  <Pencil size={16} /> Editar
                </Button>
                <Button variant="ghost" onClick={() => setExcluir(p)}>
                  <Trash2 size={16} className="text-panda-vermelho" />
                </Button>
              </div>
            </Card>
          ))}
        </div>
      )}

      <Modal open={!!editando} onClose={() => setEditando(null)} title={editando?.id ? "Editar promoção" : "Nova promoção"}>
        {editando && (
          <>
            <Field label="Título">
              <input className={inputBase} value={editando.titulo ?? ""} onChange={(e) => setEditando({ ...editando, titulo: e.target.value })} />
            </Field>
            <Field label="Descrição">
              <textarea className={inputBase} rows={3} value={editando.descricao ?? ""} onChange={(e) => setEditando({ ...editando, descricao: e.target.value })} />
            </Field>
            <Field label="Imagem do banner">
              <input type="file" accept="image/*" onChange={(e) => setArquivo(e.target.files?.[0] ?? null)} />
            </Field>
            <div className="mb-4 flex gap-4">
              <label className="flex items-center gap-2 text-sm">
                <input type="checkbox" checked={editando.ativa ?? true} onChange={(e) => setEditando({ ...editando, ativa: e.target.checked })} />
                Ativa
              </label>
              <label className="flex items-center gap-2 text-sm">
                <input type="checkbox" checked={editando.apenasAssinantes ?? false} onChange={(e) => setEditando({ ...editando, apenasAssinantes: e.target.checked })} />
                Só assinantes
              </label>
            </div>
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
          if (demoBlock("Promoção não excluída")) return;
          if (excluir) {
            await deleteDoc(doc(db, "promotions", excluir.id));
            toast.success("Promoção excluída.");
          }
        }}
        title="Excluir promoção?"
        message={`"${excluir?.titulo}" será removida permanentemente.`}
      />
    </div>
  );
}
