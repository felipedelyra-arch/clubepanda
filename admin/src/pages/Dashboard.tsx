import { useMemo } from "react";
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
} from "recharts";
import { Users, TrendingUp, DollarSign, UserMinus, Gift } from "lucide-react";
import { useCollection } from "../lib/useCollection";
import { Card, Spinner } from "../components/ui";
import type { AppUser, Subscription, Payment, Redemption } from "../lib/types";

const meses = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];

function Metric({ icon: Icon, label, value, color }: { icon: typeof Users; label: string; value: string; color: string }) {
  return (
    <Card>
      <div className="flex items-center gap-3">
        <div className="rounded-xl p-2.5" style={{ background: `${color}22`, color }}>
          <Icon size={22} />
        </div>
        <div>
          <div className="text-sm text-panda-cinza-texto">{label}</div>
          <div className="text-2xl font-bold">{value}</div>
        </div>
      </div>
    </Card>
  );
}

export function Dashboard() {
  const { data: users, loading: lu } = useCollection<AppUser>("users");
  const { data: subs } = useCollection<Subscription>("subscriptions");
  const { data: payments } = useCollection<Payment>("payments");
  const { data: redemptions } = useCollection<Redemption>("redemptions");

  const stats = useMemo(() => {
    const now = new Date();
    const ativos = subs.filter((s) => s.status === "active");
    const cancelados = subs.filter((s) => s.status === "canceled");
    const novosMes = users.filter(
      (u) => u.criadoEm && u.criadoEm.getMonth() === now.getMonth() && u.criadoEm.getFullYear() === now.getFullYear()
    );
    const pagosMes = payments.filter(
      (p) => p.data && p.data.getMonth() === now.getMonth() && p.status === "aprovado"
    );
    const mrr = pagosMes.reduce((acc, p) => acc + (p.valor || 0), 0);

    // Receita por mês (últimos 6)
    const receita = meses.map((m, i) => ({
      mes: m,
      valor: payments
        .filter((p) => p.data && p.data.getMonth() === i && p.status === "aprovado")
        .reduce((a, p) => a + (p.valor || 0), 0),
    }));

    // Crescimento de membros por mês
    const crescimento = meses.map((m, i) => ({
      mes: m,
      membros: users.filter((u) => u.criadoEm && u.criadoEm.getMonth() <= i).length,
    }));

    return {
      ativos: ativos.length,
      novosMes: novosMes.length,
      mrr,
      cancelados: cancelados.length,
      resgates: redemptions.length,
      receita,
      crescimento,
    };
  }, [users, subs, payments, redemptions]);

  if (lu) return <Spinner />;

  const brl = (v: number) => v.toLocaleString("pt-BR", { style: "currency", currency: "BRL" });

  return (
    <div>
      <h1 className="mb-6 text-2xl font-bold">Dashboard</h1>
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-5">
        <Metric icon={Users} label="Membros ativos" value={String(stats.ativos)} color="#F47A20" />
        <Metric icon={TrendingUp} label="Novos no mês" value={String(stats.novosMes)} color="#2FBF71" />
        <Metric icon={DollarSign} label="MRR" value={brl(stats.mrr)} color="#F47A20" />
        <Metric icon={UserMinus} label="Cancelamentos" value={String(stats.cancelados)} color="#E23B2E" />
        <Metric icon={Gift} label="Resgates" value={String(stats.resgates)} color="#2FBF71" />
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <Card>
          <h2 className="mb-4 font-semibold">Receita por mês</h2>
          <ResponsiveContainer width="100%" height={260}>
            <AreaChart data={stats.receita}>
              <defs>
                <linearGradient id="rev" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#F47A20" stopOpacity={0.4} />
                  <stop offset="95%" stopColor="#F47A20" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" opacity={0.15} />
              <XAxis dataKey="mes" fontSize={12} />
              <YAxis fontSize={12} />
              <Tooltip formatter={(v) => brl(Number(v))} />
              <Area type="monotone" dataKey="valor" stroke="#F47A20" fill="url(#rev)" />
            </AreaChart>
          </ResponsiveContainer>
        </Card>

        <Card>
          <h2 className="mb-4 font-semibold">Crescimento de membros</h2>
          <ResponsiveContainer width="100%" height={260}>
            <LineChart data={stats.crescimento}>
              <CartesianGrid strokeDasharray="3 3" opacity={0.15} />
              <XAxis dataKey="mes" fontSize={12} />
              <YAxis fontSize={12} />
              <Tooltip />
              <Line type="monotone" dataKey="membros" stroke="#2FBF71" strokeWidth={2} dot={false} />
            </LineChart>
          </ResponsiveContainer>
        </Card>
      </div>
    </div>
  );
}
