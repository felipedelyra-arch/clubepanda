import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { useAuth } from "./auth/AuthContext";
import { Spinner } from "./components/ui";
import { Layout } from "./components/Layout";
import { Login } from "./pages/Login";
import { Dashboard } from "./pages/Dashboard";
import { Promotions } from "./pages/Promotions";
import { Menu } from "./pages/Menu";
import { Rewards } from "./pages/Rewards";
import { Plans } from "./pages/Plans";
import { Members } from "./pages/Members";
import { Payments } from "./pages/Payments";
import { Notifications } from "./pages/Notifications";
import { Settings } from "./pages/Settings";

function Protected({ children }: { children: React.ReactNode }) {
  const { user, isAdmin, loading } = useAuth();
  if (loading) return <Spinner />;
  // Só admin autenticado passa. Resto vai pro login (que mostra "Acesso negado").
  if (!user || !isAdmin) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          element={
            <Protected>
              <Layout />
            </Protected>
          }
        >
          <Route path="/" element={<Dashboard />} />
          <Route path="/promocoes" element={<Promotions />} />
          <Route path="/cardapio" element={<Menu />} />
          <Route path="/premiacoes" element={<Rewards />} />
          <Route path="/planos" element={<Plans />} />
          <Route path="/membros" element={<Members />} />
          <Route path="/pagamentos" element={<Payments />} />
          <Route path="/notificacoes" element={<Notifications />} />
          <Route path="/configuracoes" element={<Settings />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
