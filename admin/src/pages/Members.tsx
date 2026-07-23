import { useMemo, useState } from "react";
import { doc, updateDoc } from "firebase/firestore";
import { Search } from "lucide-react";
import { toast } from "sonner";
import { db } from "../lib/firebase";
import { useCollection } from "../lib/useCollection";
import type { AppUser, Subscription } from "../lib/types";
import { Card, Badge, Spinner, Button } from "../components/ui";
import { Modal, Field, inputBase } from "../components/Modal";

export function Members() {
  const { data: users, loading } = useCollection<AppUser>("users");
  const { data: subs } = useCollection<Subscription>("subscriptions");
  const [busca, setBusca] = useState("");
  const [sel, setSel] = useState<AppUser | null>(null);
  const [pontos, setPontos] = useState(0);

  const subByUser = useMemo(() => {
    const m = new Map<string, Subscription>();
    subs.forEach((s) => { if (s.status === "active") m.set(s.userId, s); });
    return m;
  }, [subs]);

  const filtrados = users.filter((u) =>
    [u.nome, u.email, u.telefone].some((v) => v?.toLowerCase().includes(busca.toLowerCase()))
  );

  async function ajustarPontos() {
    if (!sel) return;
    await updateDoc(doc(db, "users", sel.uid), { pontos: Number(pontos) });
    toast.success("Pontos atualizados.");
    setSel(null);
  }

  if (loading) return <Spinner />;

  return (
    <div>
      <h1 className="mb-6 text-2xl font-bold">Membros</h1>
      <div className="mb-4 flex items-center gap-2 rounded-xl bg-panda-cinza dark:bg-[#262626] px-4 py-2.5 max-w-md">
        <Search size={18} className="text-panda-cinza-texto" />
        <input className="w-full bg-transparent outline-none" placeholder="Buscar por nome, e-mail, telefone" value={busca} onChange={(e) => setBusca(e.target.value)} />
      </div>

      <Card className="p-0 overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-black/5 dark:bg-white/5 text-left text-panda-cinza-texto">
            <tr>
              <th className="p-3">Nome</th><th className="p-3">E-mail</th><th className="p-3">Telefone</th>
              <th className="p-3">Status</th><th className="p-3">Pontos</th><th className="p-3"></th>
            </tr>
          </thead>
          <tbody>
            {filtrados.map((u) => (
              <tr key={u.uid} className="border-t border-black/5 dark:border-white/5">
                <td className="p-3 font-medium">{u.nome || "—"}</td>
                <td className="p-3">{u.email}</td>
                <td className="p-3">{u.telefone || "—"}</td>
                <td className="p-3">{subByUser.has(u.uid) ? <Badge color="green">Assinante</Badge> : <Badge color="gray">Free</Badge>}</td>
                <td className="p-3">{u.pontos ?? 0}</td>
                <td className="p-3 text-right">
                  <Button variant="ghost" onClick={() => { setSel(u); setPontos(u.pontos ?? 0); }}>Ajustar pontos</Button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>

      <Modal open={!!sel} onClose={() => setSel(null)} title={`Ajustar pontos — ${sel?.nome}`}>
        <Field label="Pontos"><input type="number" className={inputBase} value={pontos} onChange={(e) => setPontos(Number(e.target.value))} /></Field>
        <Button onClick={ajustarPontos} className="w-full">Salvar</Button>
      </Modal>
    </div>
  );
}
