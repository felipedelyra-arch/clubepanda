import { useMemo, useState } from "react";
import { addDoc, collection, deleteDoc, doc, updateDoc } from "firebase/firestore";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
import { Plus, Pencil, Trash2, Star, EyeOff, UtensilsCrossed } from "lucide-react";
import { toast } from "sonner";
import { db, storage } from "../lib/firebase";
import { useCollection } from "../lib/useCollection";
import type { MenuItem } from "../lib/types";
import {
  Card,
  Button,
  Badge,
  Spinner,
  EmptyState,
  ErrorState,
  PageHeader,
} from "../components/ui";
import { Modal, ConfirmDialog, Field, inputBase } from "../components/Modal";
import { demoBlock } from "../lib/demo";
import { brl } from "../lib/format";

const vazio: Partial<MenuItem> = {
  nome: "",
  descricao: "",
  preco: 0,
  categoria: "",
  imagem: null,
  destaque: false,
  disponivel: true,
  ordem: 0,
};

export function Menu() {
  const { data, loading, error } = useCollection<MenuItem>("menu");
  const [editando, setEditando] = useState<Partial<MenuItem> | null>(null);
  const [excluir, setExcluir] = useState<MenuItem | null>(null);
  const [arquivo, setArquivo] = useState<File | null>(null);
  const [salvando, setSalvando] = useState(false);

  /**
   * Mesma ordenação do app (`cardapioProvider`): prato por `ordem` e desempate
   * pelo nome; categoria entra na posição do menor `ordem` que ela tem dentro.
   * Se mudar aqui, mude lá — senão o painel mostra uma ordem e o app, outra.
   */
  const categorias = useMemo(() => {
    const mapa = new Map<string, MenuItem[]>();
    data.forEach((i) => {
      const chave = i.categoria?.trim() || "Outros";
      if (!mapa.has(chave)) mapa.set(chave, []);
      mapa.get(chave)!.push(i);
    });
    const lista = [...mapa.entries()].map(([nome, itens]) => ({
      nome,
      itens: itens.sort((a, b) => a.ordem - b.ordem || a.nome.localeCompare(b.nome)),
    }));
    return lista.sort(
      (a, b) => a.itens[0].ordem - b.itens[0].ordem || a.nome.localeCompare(b.nome)
    );
  }, [data]);

  // Sugestões do campo categoria: o que já existe. Evita "Sushi" e "sushis"
  // virarem duas seções no app por causa de digitação.
  const nomesCategorias = useMemo(
    () => [...new Set(data.map((i) => i.categoria?.trim()).filter(Boolean))].sort(),
    [data]
  );

  function abrir(item?: MenuItem) {
    setEditando(item ?? { ...vazio });
    setArquivo(null);
  }

  async function salvar() {
    if (!editando?.nome?.trim()) return toast.error("Informe o nome do prato.");
    if (demoBlock("Prato não salvo")) return setEditando(null);
    setSalvando(true);
    try {
      let imagem = editando.imagem ?? null;
      if (arquivo) {
        const r = ref(storage, `menu/${Date.now()}_${arquivo.name}`);
        await uploadBytes(r, arquivo);
        imagem = await getDownloadURL(r);
      }
      const payload = {
        nome: editando.nome.trim(),
        descricao: editando.descricao?.trim() ?? "",
        preco: Number(editando.preco ?? 0),
        categoria: editando.categoria?.trim() || "Outros",
        imagem,
        destaque: editando.destaque ?? false,
        disponivel: editando.disponivel ?? true,
        ordem: Number(editando.ordem ?? 0),
      };
      if (editando.id) await updateDoc(doc(db, "menu", editando.id), payload);
      else await addDoc(collection(db, "menu"), payload);
      toast.success("Prato salvo.");
      setEditando(null);
      setArquivo(null);
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setSalvando(false);
    }
  }

  /** Liga/desliga sem abrir o formulário — é o gesto do dia a dia. */
  async function alternar(item: MenuItem, campo: "destaque" | "disponivel") {
    if (demoBlock("Alteração não salva")) return;
    try {
      await updateDoc(doc(db, "menu", item.id), { [campo]: !item[campo] });
    } catch (e) {
      toast.error((e as Error).message);
    }
  }

  if (loading) return <Spinner />;
  if (error) return <ErrorState mensagem={error} />;

  const fora = data.filter((i) => !i.disponivel).length;
  const destaques = data.filter((i) => i.destaque && i.disponivel).length;

  return (
    <div>
      <PageHeader
        titulo="Cardápio"
        descricao={
          data.length
            ? `${data.length} prato(s) · ${destaques} em destaque na Home` +
              (fora ? ` · ${fora} fora do ar` : "")
            : undefined
        }
        acao={
          <Button onClick={() => abrir()}>
            <Plus size={18} /> Novo prato
          </Button>
        }
      />

      {data.length === 0 ? (
        <EmptyState
          mensagem="Cardápio vazio. Cadastre o primeiro prato e ele aparece no app na hora."
          acao={
            <Button onClick={() => abrir()}>
              <Plus size={18} /> Novo prato
            </Button>
          }
        />
      ) : (
        <div className="flex flex-col gap-6">
          {categorias.map((cat) => (
            <section key={cat.nome}>
              <h2 className="mb-3 flex items-center gap-2 font-semibold">
                <span className="h-0.5 w-5 rounded bg-panda-laranja" />
                {cat.nome}
                <span className="text-sm font-normal text-panda-cinza-texto">
                  {cat.itens.length}
                </span>
              </h2>
              <div className="flex flex-col gap-2">
                {cat.itens.map((i) => (
                  <Card key={i.id} className={i.disponivel ? "" : "opacity-60"}>
                    <div className="flex items-start gap-3">
                      <div className="h-16 w-16 shrink-0 overflow-hidden rounded-xl bg-panda-laranja/10">
                        {i.imagem ? (
                          <img src={i.imagem} alt="" className="h-full w-full object-cover" />
                        ) : (
                          <div className="flex h-full w-full items-center justify-center text-panda-laranja">
                            <UtensilsCrossed size={20} />
                          </div>
                        )}
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="font-medium">{i.nome}</span>
                          {i.destaque && <Badge color="orange">Destaque</Badge>}
                          {!i.disponivel && <Badge color="gray">Fora do ar</Badge>}
                        </div>
                        {i.descricao && (
                          <p className="mt-0.5 line-clamp-2 text-sm text-panda-cinza-texto">
                            {i.descricao}
                          </p>
                        )}
                        <div className="tabular mt-1 font-semibold text-panda-laranja">
                          {brl(i.preco)}
                        </div>
                      </div>
                    </div>

                    <div className="mt-3 flex flex-wrap gap-2">
                      <Button variant="outline" className="flex-1" onClick={() => abrir(i)}>
                        <Pencil size={16} /> Editar
                      </Button>
                      <Button
                        variant="ghost"
                        title={i.destaque ? "Tirar da Home" : "Colocar na Home"}
                        onClick={() => alternar(i, "destaque")}
                      >
                        <Star
                          size={16}
                          className={i.destaque ? "text-panda-laranja" : ""}
                        />
                      </Button>
                      <Button
                        variant="ghost"
                        title={i.disponivel ? "Tirar do ar" : "Voltar pro ar"}
                        onClick={() => alternar(i, "disponivel")}
                      >
                        <EyeOff size={16} className={i.disponivel ? "" : "text-panda-laranja"} />
                      </Button>
                      <Button variant="ghost" onClick={() => setExcluir(i)}>
                        <Trash2 size={16} className="text-panda-vermelho" />
                      </Button>
                    </div>
                  </Card>
                ))}
              </div>
            </section>
          ))}
        </div>
      )}

      <Modal
        open={!!editando}
        onClose={() => setEditando(null)}
        title={editando?.id ? "Editar prato" : "Novo prato"}
      >
        {editando && (
          <>
            <Field label="Nome">
              <input
                className={inputBase}
                value={editando.nome ?? ""}
                onChange={(e) => setEditando({ ...editando, nome: e.target.value })}
                placeholder="Combinado especial"
              />
            </Field>
            <Field label="Descrição">
              <textarea
                className={inputBase}
                rows={2}
                value={editando.descricao ?? ""}
                onChange={(e) => setEditando({ ...editando, descricao: e.target.value })}
                placeholder="20 peças variadas: sashimi, uramaki e niguiri."
              />
            </Field>
            <div className="grid gap-x-3 sm:grid-cols-2">
              <Field label="Preço (R$)">
                <input
                  type="number"
                  step="0.01"
                  min="0"
                  className={inputBase}
                  value={editando.preco ?? 0}
                  onChange={(e) => setEditando({ ...editando, preco: Number(e.target.value) })}
                />
              </Field>
              <Field label="Ordem (menor aparece primeiro)">
                <input
                  type="number"
                  className={inputBase}
                  value={editando.ordem ?? 0}
                  onChange={(e) => setEditando({ ...editando, ordem: Number(e.target.value) })}
                />
              </Field>
            </div>
            <Field label="Categoria">
              <input
                className={inputBase}
                list="categorias-menu"
                value={editando.categoria ?? ""}
                onChange={(e) => setEditando({ ...editando, categoria: e.target.value })}
                placeholder="Combinados & Sushi"
              />
              <datalist id="categorias-menu">
                {nomesCategorias.map((c) => (
                  <option key={c} value={c} />
                ))}
              </datalist>
            </Field>
            <Field label="Foto do prato">
              <input
                type="file"
                accept="image/*"
                onChange={(e) => setArquivo(e.target.files?.[0] ?? null)}
              />
            </Field>
            <label className="mb-2 flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={editando.destaque ?? false}
                onChange={(e) => setEditando({ ...editando, destaque: e.target.checked })}
              />
              Mostrar na Home, em "Destaques do cardápio"
            </label>
            <label className="mb-4 flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={editando.disponivel ?? true}
                onChange={(e) => setEditando({ ...editando, disponivel: e.target.checked })}
              />
              Disponível — desmarque pra sumir do app sem apagar
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
          if (demoBlock("Prato não excluído")) return;
          if (excluir) {
            await deleteDoc(doc(db, "menu", excluir.id));
            toast.success("Prato excluído.");
          }
        }}
        title="Excluir prato?"
        message={`"${excluir?.nome}" sai do cardápio pra sempre. Pra tirar do ar sem perder, use o botão de olho.`}
      />
    </div>
  );
}
