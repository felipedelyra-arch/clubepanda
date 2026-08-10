import { useState } from "react";
import { Navigate } from "react-router-dom";
import { signInWithEmailAndPassword, sendPasswordResetEmail } from "firebase/auth";
import { toast } from "sonner";
import { auth } from "../lib/firebase";
import { useAuth } from "../auth/AuthContext";
import { PandaLogo } from "../components/PandaLogo";
import { Button } from "../components/ui";
import { inputBase } from "../components/Modal";

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

  // Login resolvido: sai do formulário. Sem isto o admin autentica e fica
  // olhando a mesma tela — nada mais nesta rota tira ele daqui.
  if (!loading && user && isAdmin) return <Navigate to="/" replace />;

  return (
    // min-h + centro: no celular o teclado abrindo encolhe a viewport e o
    // h-screen cortava o botão Entrar.
    <div className="flex min-h-full items-center justify-center bg-fundo p-6">
      <div className="w-full max-w-sm">
        <div className="mb-7 flex flex-col items-center text-center">
          <PandaLogo size={104} />
          <div className="rotulo mt-5">Painel do restaurante</div>
          <h1 className="display mt-2 text-[30px] leading-none">PandaVip</h1>
          <p className="mt-2.5 text-sm text-tinta-2">
            Acesso restrito à equipe Tio Panda.
          </p>
        </div>

        {acessoNegado ? (
          <div className="rounded-2xl border border-erro/30 bg-erro/8 p-4 text-sm text-erro-tinta">
            <strong className="font-semibold">Acesso negado.</strong> Esta conta
            existe, mas não é administradora. Peça a quem já tem acesso para
            liberar em Configurações.
          </div>
        ) : (
          <form onSubmit={entrar} className="flex flex-col gap-3">
            <input
              type="email"
              autoComplete="email"
              placeholder="E-mail"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className={inputBase}
              required
            />
            <input
              type="password"
              autoComplete="current-password"
              placeholder="Senha"
              value={senha}
              onChange={(e) => setSenha(e.target.value)}
              className={inputBase}
              required
            />
            <Button type="submit" disabled={busy}>
              {busy ? "Entrando..." : "Entrar"}
            </Button>
            <button
              type="button"
              onClick={recuperar}
              className="mt-1 self-center text-sm font-medium text-tinta-3 transition-colors hover:text-marca-tinta"
            >
              Esqueci a senha
            </button>
          </form>
        )}
      </div>
    </div>
  );
}
