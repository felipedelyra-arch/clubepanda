import { useState } from "react";
import { signInWithEmailAndPassword, sendPasswordResetEmail } from "firebase/auth";
import { toast } from "sonner";
import { auth } from "../lib/firebase";
import { useAuth } from "../auth/AuthContext";
import { PandaLogo } from "../components/PandaLogo";
import { Button } from "../components/ui";

export function Login() {
  const { user, isAdmin, loading } = useAuth();
  const [email, setEmail] = useState("");
  const [senha, setSenha] = useState("");
  const [busy, setBusy] = useState(false);

  async function entrar(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    try {
      await signInWithEmailAndPassword(auth, email.trim(), senha);
    } catch {
      toast.error("E-mail ou senha incorretos.");
    } finally {
      setBusy(false);
    }
  }

  async function recuperar() {
    if (!email.trim()) return toast.error("Digite seu e-mail.");
    await sendPasswordResetEmail(auth, email.trim());
    toast.success("E-mail de recuperação enviado.");
  }

  // Logado mas não-admin => bloqueia.
  const acessoNegado = !loading && user && !isAdmin;

  return (
    // min-h + centro: no celular o teclado abrindo encolhe a viewport e o
    // h-screen cortava o botão Entrar.
    <div className="flex min-h-full items-center justify-center p-6">
      <div className="w-full max-w-sm">
        <div className="mb-8 flex justify-center">
          <PandaLogo size={64} />
        </div>
        <h1 className="mb-1 text-2xl font-bold">Painel do Admin</h1>
        <p className="mb-6 text-panda-cinza-texto">Acesso restrito à equipe Tio Panda.</p>

        {acessoNegado ? (
          <div className="rounded-xl bg-panda-vermelho/10 p-4 text-panda-vermelho">
            Acesso negado. Esta conta não é administradora.
          </div>
        ) : (
          <form onSubmit={entrar} className="flex flex-col gap-3">
            <input
              type="email"
              placeholder="E-mail"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="min-h-12 rounded-xl bg-panda-cinza px-4 py-3 outline-none focus:ring-2 focus:ring-panda-laranja dark:bg-panda-superficie-dark"
              required
            />
            <input
              type="password"
              placeholder="Senha"
              value={senha}
              onChange={(e) => setSenha(e.target.value)}
              className="min-h-12 rounded-xl bg-panda-cinza px-4 py-3 outline-none focus:ring-2 focus:ring-panda-laranja dark:bg-panda-superficie-dark"
              required
            />
            <button
              type="button"
              onClick={recuperar}
              className="self-end text-sm text-panda-laranja"
            >
              Esqueci a senha
            </button>
            <Button type="submit" disabled={busy}>
              {busy ? "Entrando..." : "Entrar"}
            </Button>
          </form>
        )}
      </div>
    </div>
  );
}
