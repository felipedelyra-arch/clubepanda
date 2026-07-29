import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import {
  LayoutDashboard,
  Megaphone,
  Gift,
  CreditCard,
  Users,
  Receipt,
  Bell,
  Settings,
  LogOut,
  Moon,
  Sun,
  MoreHorizontal,
  X,
} from "lucide-react";
import { useEffect, useState } from "react";
import type { ComponentType } from "react";
import { PandaLogo } from "./PandaLogo";
import { useAuth } from "../auth/AuthContext";
import { IS_DEMO } from "../lib/demo";

interface ItemNav {
  to: string;
  label: string;
  icon: ComponentType<{ size?: number }>;
  end?: boolean;
}

const nav: ItemNav[] = [
  { to: "/", label: "Início", icon: LayoutDashboard, end: true },
  { to: "/promocoes", label: "Promoções", icon: Megaphone },
  { to: "/premiacoes", label: "Premiações", icon: Gift },
  { to: "/membros", label: "Membros", icon: Users },
  { to: "/planos", label: "Plano", icon: CreditCard },
  { to: "/pagamentos", label: "Pagamentos", icon: Receipt },
  { to: "/notificacoes", label: "Notificações", icon: Bell },
  { to: "/configuracoes", label: "Configurações", icon: Settings },
];

/**
 * Barra de baixo do celular: o que o dono abre em pé no salão, no meio do
 * serviço. Ordenado por frequência de uso, não por hierarquia de menu — daí
 * Premiações (validar resgate no caixa) vir antes de Pagamentos.
 */
const navCelular = nav.slice(0, 4);
const navGaveta = nav.slice(4);

function estiloItem(isActive: boolean) {
  return `flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition ${
    isActive
      ? "bg-panda-laranja text-white"
      : "text-panda-cinza-texto hover:bg-black/5 dark:hover:bg-white/5"
  }`;
}

export function Layout() {
  const { logout } = useAuth();
  const navigate = useNavigate();
  const { pathname } = useLocation();
  const [dark, setDark] = useState(
    () => localStorage.getItem("panda-theme") === "dark"
  );
  const [gaveta, setGaveta] = useState(false);

  useEffect(() => {
    document.documentElement.classList.toggle("dark", dark);
    localStorage.setItem("panda-theme", dark ? "dark" : "light");
  }, [dark]);

  // Trocar de tela fecha a gaveta — senão ela cobre o destino recém-aberto.
  useEffect(() => setGaveta(false), [pathname]);

  const atual = nav.find((n) => (n.end ? pathname === n.to : pathname.startsWith(n.to)));

  async function sair() {
    await logout();
    navigate("/login");
  }

  return (
    <div className="flex min-h-full md:h-screen">
      {/* ---- sidebar (tablet pra cima) ---- */}
      <aside className="hidden w-64 shrink-0 flex-col border-r border-black/5 p-4 md:flex dark:border-white/10">
        <div className="px-2 py-3">
          <PandaLogo size={36} />
        </div>
        <nav className="mt-6 flex flex-1 flex-col gap-1">
          {nav.map(({ to, label, icon: Icon, end }) => (
            <NavLink key={to} to={to} end={end} className={({ isActive }) => estiloItem(isActive)}>
              <Icon size={18} />
              {label}
            </NavLink>
          ))}
        </nav>
        <div className="flex flex-col gap-1">
          <BotaoTema dark={dark} onToggle={() => setDark((d) => !d)} />
          <BotaoSair onSair={sair} />
        </div>
      </aside>

      {/* ---- topo do celular ---- */}
      <header className="fixed inset-x-0 top-0 z-30 flex h-14 items-center gap-3 border-b border-black/5 bg-white/90 px-4 backdrop-blur md:hidden dark:border-white/10 dark:bg-[#121212]/90">
        <PandaLogo size={28} />
        <span className="font-semibold">{atual?.label ?? "Painel"}</span>
      </header>

      <main className="flex-1 overflow-y-auto px-4 pb-28 pt-18 md:px-8 md:pb-8 md:pt-8">
        {IS_DEMO && (
          <div className="mb-5 rounded-xl bg-panda-laranja/15 px-4 py-2.5 text-sm font-medium text-panda-laranja md:mb-6">
            🐼 Modo demonstração — dados fictícios. Salvar, excluir e enviar estão desligados.
          </div>
        )}
        <Outlet />
      </main>

      {/* ---- barra de baixo (celular) ---- */}
      <nav className="fixed inset-x-0 bottom-0 z-30 flex border-t border-black/5 bg-white/95 pb-[env(safe-area-inset-bottom)] backdrop-blur md:hidden dark:border-white/10 dark:bg-[#121212]/95">
        {navCelular.map(({ to, label, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            className={({ isActive }) =>
              `flex flex-1 flex-col items-center gap-1 py-2 text-[11px] font-medium transition ${
                isActive ? "text-panda-laranja" : "text-panda-cinza-texto"
              }`
            }
          >
            <Icon size={22} />
            {label}
          </NavLink>
        ))}
        <button
          onClick={() => setGaveta(true)}
          className={`flex flex-1 flex-col items-center gap-1 py-2 text-[11px] font-medium transition ${
            navGaveta.some((n) => pathname.startsWith(n.to))
              ? "text-panda-laranja"
              : "text-panda-cinza-texto"
          }`}
        >
          <MoreHorizontal size={22} />
          Mais
        </button>
      </nav>

      {/* ---- gaveta "Mais" (celular) ---- */}
      {gaveta && (
        <div
          className="fixed inset-0 z-40 flex items-end bg-black/40 md:hidden"
          onClick={() => setGaveta(false)}
        >
          <div
            className="w-full rounded-t-[22px] bg-white p-4 pb-[calc(1rem+env(safe-area-inset-bottom))] dark:bg-panda-card-dark"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="mb-3 flex items-center justify-between">
              <span className="font-semibold">Mais</span>
              <button
                onClick={() => setGaveta(false)}
                aria-label="Fechar"
                className="text-panda-cinza-texto"
              >
                <X size={20} />
              </button>
            </div>
            <div className="flex flex-col gap-1">
              {navGaveta.map(({ to, label, icon: Icon }) => (
                <NavLink key={to} to={to} className={({ isActive }) => estiloItem(isActive)}>
                  <Icon size={18} />
                  {label}
                </NavLink>
              ))}
              <div className="my-2 h-px bg-black/5 dark:bg-white/10" />
              <BotaoTema dark={dark} onToggle={() => setDark((d) => !d)} />
              <BotaoSair onSair={sair} />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function BotaoTema({ dark, onToggle }: { dark: boolean; onToggle: () => void }) {
  return (
    <button
      onClick={onToggle}
      className="flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-panda-cinza-texto hover:bg-black/5 dark:hover:bg-white/5"
    >
      {dark ? <Sun size={18} /> : <Moon size={18} />}
      {dark ? "Tema claro" : "Tema escuro"}
    </button>
  );
}

function BotaoSair({ onSair }: { onSair: () => void }) {
  return (
    <button
      onClick={onSair}
      className="flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-panda-vermelho hover:bg-panda-vermelho/10"
    >
      <LogOut size={18} />
      Sair
    </button>
  );
}
