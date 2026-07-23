import { useState } from "react";
import { doc, setDoc } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { UserPlus, UserMinus } from "lucide-react";
import { toast } from "sonner";
import { db, functions } from "../lib/firebase";
import { useCollection } from "../lib/useCollection";
import type { AppUser } from "../lib/types";
import { Card, Button, Badge } from "../components/ui";
import { Field, inputBase } from "../components/Modal";

export function Settings() {
  const { data: users } = useCollection<AppUser>("users");
  const [nome, setNome] = useState("Tio Panda");
  const [uidAlvo, setUidAlvo] = useState("");

  const admins = users.filter((u) => u.role === "admin");

  async function salvarRestaurante() {
    await setDoc(doc(db, "config", "restaurante"), { nome }, { merge: true });
    toast.success("Dados salvos.");
  }

  async function alterarAdmin(targetUid: string, makeAdmin: boolean) {
    try {
      await httpsCallable(functions, "setAdminRole")({ targetUid, makeAdmin });
      toast.success(makeAdmin ? "Admin concedido." : "Admin revogado.");
      setUidAlvo("");
    } catch (e) {
      toast.error((e as Error).message);
    }
  }

  return (
    <div className="max-w-2xl">
      <h1 className="mb-6 text-2xl font-bold">Configurações</h1>

      <Card className="mb-6">
        <h2 className="mb-3 font-semibold">Dados do restaurante</h2>
        <Field label="Nome"><input className={inputBase} value={nome} onChange={(e) => setNome(e.target.value)} /></Field>
        <Button onClick={salvarRestaurante}>Salvar</Button>
      </Card>

      <Card>
        <h2 className="mb-3 font-semibold">Administradores</h2>
        <div className="mb-4 space-y-2">
          {admins.map((a) => (
            <div key={a.uid} className="flex items-center justify-between rounded-xl bg-white dark:bg-[#1e1e1e] px-4 py-2">
              <div>
                <div className="font-medium">{a.nome || a.email}</div>
                <div className="text-xs text-panda-cinza-texto">{a.uid}</div>
              </div>
              <div className="flex items-center gap-2">
                <Badge color="orange">admin</Badge>
                <Button variant="ghost" onClick={() => alterarAdmin(a.uid, false)}>
                  <UserMinus size={16} className="text-panda-vermelho" />
                </Button>
              </div>
            </div>
          ))}
        </div>
        <div className="flex gap-2">
          <input className={inputBase} placeholder="UID do usuário para promover a admin" value={uidAlvo} onChange={(e) => setUidAlvo(e.target.value)} />
          <Button onClick={() => alterarAdmin(uidAlvo, true)} disabled={!uidAlvo}>
            <UserPlus size={18} /> Conceder
          </Button>
        </div>
        <p className="mt-2 text-xs text-panda-cinza-texto">
          O primeiro admin é criado via script (ver firebase/README.md). Depois, gerencie por aqui.
        </p>
      </Card>
    </div>
  );
}
