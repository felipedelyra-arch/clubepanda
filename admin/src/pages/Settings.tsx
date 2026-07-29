import { useEffect, useState } from "react";
import { doc, setDoc } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { UserPlus, UserMinus, AlertTriangle } from "lucide-react";
import { toast } from "sonner";
import { db, functions } from "../lib/firebase";
import { useCollection, useDoc } from "../lib/useCollection";
import type { AppUser, Restaurante } from "../lib/types";
import { Card, Button, Badge, Spinner, PageHeader } from "../components/ui";
import { Field, inputBase } from "../components/Modal";
import { demoBlock } from "../lib/demo";

const vazio: Restaurante = {
  nome: "",
  telefone: "",
  whatsapp: "",
  endereco: "",
  politicaPrivacidadeUrl: "",
  termosUrl: "",
  playStoreUrl: "",
  appStoreUrl: "",
};

/** Mesmos valores de exemplo de `app/lib/core/restaurante.dart`. */
const placeholders = [
  "551430000000",
  "5514990000000",
  "Tio Panda restaurante",
  "https://tiopanda.com.br/privacidade",
  "https://tiopanda.com.br/termos",
  "https://play.google.com/store/apps/details?id=com.tiopanda.clube",
  "https://apps.apple.com/app/id000000000",
];

const soDigitos = (s: string) => s.replace(/\D/g, "");

export function Settings() {
  const { data: users } = useCollection<AppUser>("users");
  const { data: salvo, loading } = useDoc<Restaurante>("config/restaurante");
  const [form, setForm] = useState<Restaurante>(vazio);
  const [salvando, setSalvando] = useState(false);
  const [uidAlvo, setUidAlvo] = useState("");

  // Preenche o formulário quando o doc chega (e a cada mudança no Firestore).
  useEffect(() => {
    if (salvo) setForm({ ...vazio, ...salvo });
  }, [salvo]);

  const admins = users.filter((u) => u.role === "admin");
  const pendentes = Object.values(form).filter((v) =>
    placeholders.includes(String(v))
  ).length;

  const set = (campo: keyof Restaurante) => (e: { target: { value: string } }) =>
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
      toast.success("Dados salvos.");
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
      toast.success(makeAdmin ? "Admin concedido." : "Admin revogado.");
      setUidAlvo("");
    } catch (e) {
      toast.error((e as Error).message);
    }
  }

  if (loading) return <Spinner />;

  return (
    <div className="max-w-2xl">
      <PageHeader titulo="Configurações" />

      <Card className="mb-6">
        <h2 className="mb-1 font-semibold">Dados do restaurante</h2>
        <p className="mb-4 text-sm text-panda-cinza-texto">
          Usados pelos botões de contato do app (Ligar, WhatsApp, Como chegar) e
          pelos links de política/termos exigidos pelas lojas.
        </p>

        {pendentes > 0 && (
          <div className="mb-4 flex gap-2 rounded-xl bg-panda-laranja/15 p-3 text-sm text-panda-laranja">
            <AlertTriangle size={18} className="mt-0.5 shrink-0" />
            <span>
              {pendentes} campo(s) ainda com valor de exemplo. Enquanto estiver
              assim, os botões do app abrem número/endereço fictício.
            </span>
          </div>
        )}

        <Field label="Nome">
          <input className={inputBase} value={form.nome} onChange={set("nome")} placeholder="Tio Panda" />
        </Field>
        <Field label="Telefone (DDI + DDD + número, só dígitos)">
          <input className={inputBase} value={form.telefone} onChange={set("telefone")} placeholder="551430000000" inputMode="numeric" />
        </Field>
        <Field label="WhatsApp (DDI + DDD + número, só dígitos)">
          <input className={inputBase} value={form.whatsapp} onChange={set("whatsapp")} placeholder="5514990000000" inputMode="numeric" />
        </Field>
        <Field label="Endereço (como buscar no Google Maps)">
          <input className={inputBase} value={form.endereco} onChange={set("endereco")} placeholder="Rua X, 123 — Bauru/SP" />
        </Field>
        <Field label="URL da política de privacidade">
          <input className={inputBase} value={form.politicaPrivacidadeUrl} onChange={set("politicaPrivacidadeUrl")} placeholder="https://…" />
        </Field>
        <Field label="URL dos termos de uso">
          <input className={inputBase} value={form.termosUrl} onChange={set("termosUrl")} placeholder="https://…" />
        </Field>
        <Field label="Link na Play Store">
          <input className={inputBase} value={form.playStoreUrl} onChange={set("playStoreUrl")} placeholder="https://play.google.com/…" />
        </Field>
        <Field label="Link na App Store">
          <input className={inputBase} value={form.appStoreUrl} onChange={set("appStoreUrl")} placeholder="https://apps.apple.com/…" />
        </Field>

        <Button onClick={salvarRestaurante} disabled={salvando}>
          {salvando ? "Salvando..." : "Salvar"}
        </Button>
      </Card>

      <Card>
        <h2 className="mb-3 font-semibold">Administradores</h2>
        <div className="mb-4 space-y-2">
          {admins.map((a) => (
            <div key={a.uid} className="flex items-center justify-between gap-3 rounded-xl bg-white px-4 py-2 dark:bg-panda-card-dark">
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
