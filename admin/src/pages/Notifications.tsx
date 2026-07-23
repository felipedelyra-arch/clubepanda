import { useState } from "react";
import { httpsCallable } from "firebase/functions";
import { Send } from "lucide-react";
import { toast } from "sonner";
import { functions } from "../lib/firebase";
import { Card, Button } from "../components/ui";
import { Field, inputBase } from "../components/Modal";

export function Notifications() {
  const [titulo, setTitulo] = useState("");
  const [corpo, setCorpo] = useState("");
  const [onlySubscribers, setOnlySubscribers] = useState(false);
  const [enviando, setEnviando] = useState(false);

  async function enviar() {
    if (!titulo || !corpo) return toast.error("Preencha título e mensagem.");
    setEnviando(true);
    try {
      const res = await httpsCallable(functions, "sendPush")({ titulo, corpo, onlySubscribers });
      const n = (res.data as { enviados: number }).enviados;
      toast.success(`Push enviado para ${n} dispositivo(s).`);
      setTitulo("");
      setCorpo("");
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setEnviando(false);
    }
  }

  return (
    <div className="max-w-xl">
      <h1 className="mb-6 text-2xl font-bold">Notificações</h1>
      <Card>
        <Field label="Título"><input className={inputBase} value={titulo} onChange={(e) => setTitulo(e.target.value)} placeholder="🐼 Novidade no Clube Panda" /></Field>
        <Field label="Mensagem"><textarea className={inputBase} rows={3} value={corpo} onChange={(e) => setCorpo(e.target.value)} placeholder="Rodízio com 20% off nesta semana!" /></Field>
        <label className="mb-4 flex items-center gap-2 text-sm">
          <input type="checkbox" checked={onlySubscribers} onChange={(e) => setOnlySubscribers(e.target.checked)} />
          Enviar só para assinantes ativos
        </label>
        <Button onClick={enviar} disabled={enviando} className="w-full">
          <Send size={18} /> {enviando ? "Enviando..." : "Enviar push"}
        </Button>
      </Card>
    </div>
  );
}
