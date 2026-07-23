import { NavLink, Outlet, useNavigate } from "react-router-dom";
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
} from "lucide-react";
import { useEffect, useState } from "react";
import { PandaLogo } from "./PandaLogo";
import { useAuth } from "../auth/AuthContext";
import { IS_DEMO } from "../lib/demo";

const nav = [
  { to: "/", label: "Dashboard", icon: LayoutDashboard, end: true },
  { to: "/promocoes", label: "Promoções", icon: Megaphone },
  { to: "/premiacoes", label: "Premiações", icon: Gift },
  { to: "/planos", label: "Planos", icon: CreditCard },
  { to: "/membros", label: "Membros", icon: Users },
  { to: "/pagamentos", label: "Pagamentos", icon: Receipt },
  { to: "/notificacoes", label: "Notificações", icon: Bell },
  { to: "/configuracoes", label: "Configurações", icon: Settings },
];

export function Layout() {
  const { logout } = useAuth();
  const navigate = useNavigate();
  const [dark, setDark] = useState(
    () => localStorage.getItem("panda-theme") === "dark"
  );

  useEffect(() => {
    document.documentElement.classList.toggle("dark", dark);
    localStorage.setItem("panda-theme", dark ? "dark" : "light");
  }, [dark]);

  return (
    <div className="flex h-screen">
      <aside className="flex w-64 flex-col border-r border-black/5 dark:border-white/10 p-4">
        <div className="px-2 py-3">
          <PandaLogo size={36} />
        </div>
        <nav className="mt-6 flex flex-1 flex-col gap-1">
          {nav.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                `flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition ${
                  isActive
                    ? "bg-panda-laranja text-white"
                    : "text-panda-cinza-texto hover:bg-black/5 dark:hover:bg-white/5"
                }`
              }
            >
              <Icon size={18} />
              {label}
            </NavLink>
          ))}
        </nav>
        <div className="flex flex-col gap-1">
          <button
            onClick={() => setDark((d) => !d)}
            className="flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-panda-cinza-texto hover:bg-black/5 dark:hover:bg-white/5"
          >
            {dark ? <Sun size={18} /> : <Moon size={18} />}
            {dark ? "Tema claro" : "Tema escuro"}
          </button>
          <button
            onClick={async () => {
              await logout();
              navigate("/login");
            }}
            className="flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-panda-vermelho hover:bg-panda-vermelho/10"
          >
            <LogOut size={18} />
            Sair
          </button>
        </div>
      </aside>
      <main className="flex-1 overflow-y-auto p-8">
        {IS_DEMO && (
          <div className="mb-6 rounded-xl bg-panda-laranja/15 px-4 py-2.5 text-sm font-medium text-panda-laranja">
            🐼 Modo demonstração — dados fictícios. Salvar/excluir/enviar estão desativados.
          </div>
        )}
        <Outlet />
      </main>
    </div>
  );
}
