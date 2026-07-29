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
import { Card, Spinner, ErrorState, PageHeader } from "../components/ui";
import type { AppUser, Subscription, Payment, Redemption } from "../lib/types";
import { brl } from "../lib/format";

const meses = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];

/** Chave ano-mês. Comparar só o mês somaria jan/2025 com jan/2026. */
const chaveMes = (d: Date) => `${d.getFullYear()}-${d.getMonth()}`;

function Metric({ icon: Icon, label, value, color }: { icon: typeof Users; label: string; value: string; color: string }) {
  return (
    <Card>
      {/* Empilhado no celular: lado a lado, o rótulo de duas palavras quebrava
          e desalinhava a altura dos cartões vizinhos. */}
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:gap-3">
        <div className="w-fit rounded-xl p-2.5" style={{ background: `${color}22`, color }}>
          <Icon size={20} />
        </div>
        <div className="min-w-0">
          <div className="text-xs text-panda-cinza-texto sm:text-sm">{label}</div>
          <div className="tabular text-xl font-bold sm:text-2xl">{value}</div>
        </div>
      </div>
    </Card>
  );
}

export function Dashboard() {
  const { data: users, loading: lu, error: eu } = useCollection<AppUser>("users");
  const { data: subs, error: es } = useCollection<Subscription>("subscriptions");
  const { data: payments, error: ep } = useCollection<Payment>("payments");
  const { data: redemptions, error: er } = useCollection<Redemption>("redemptions");
  const erro = eu || es || ep || er;

  const stats = useMemo(() => {
    const now = new Date();
    const ativos = subs.filter((s) => s.status === "active");
    const cancelados = subs.filter((s) => s.status === "canceled");
    const novosMes = users.filter(
      (u) => u.criadoEm && chaveMes(u.criadoEm) === chaveMes(now)
    );
    const pagosMes = payments.filter(
      (p) => p.data && chaveMes(p.data) === chaveMes(now) && p.status === "aprovado"
    );
    const mrr = pagosMes.reduce((acc, p) => acc + (p.valor || 0), 0);

    // Janela móvel dos últimos 6 meses, terminando no mês atual.
    const janela = Array.from({ length: 6 }, (_, k) => {
      const d = new Date(now.getFullYear(), now.getMonth() - (5 - k), 1);
      const outroAno = d.getFullYear() !== now.getFullYear();
      return {
        chave: chaveMes(d),
        // Vira do ano: rotula "Dez/25" pra não parecer o dezembro deste ano.
        rotulo: meses[d.getMonth()] + (outroAno ? `/${String(d.getFullYear()).slice(2)}` : ""),
        // Último instante do mês, pro acumulado de membros.
        fim: new Date(d.getFullYear(), d.getMonth() + 1, 0, 23, 59, 59, 999),
      };
    });

    const receita = janela.map((j) => ({
      mes: j.rotulo,
      valor: payments
        .filter((p) => p.data && chaveMes(p.data) === j.chave && p.status === "aprovado")
        .reduce((a, p) => a + (p.valor || 0), 0),
    }));

    // Acumulado: quantos membros existiam no fim de cada mês da janela.
    const crescimento = janela.map((j) => ({
      mes: j.rotulo,
      membros: users.filter((u) => u.criadoEm && u.criadoEm <= j.fim).length,
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

  return (
    <div>
      <PageHeader titulo="Início" descricao="Como o Clube está indo neste mês" />
      {erro && (
        <div className="mb-6">
          <ErrorState mensagem={erro} />
        </div>
      )}
      <div className="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-5">
        <Metric icon={Users} label="Membros ativos" value={String(stats.ativos)} color="#F47A20" />
        <Metric icon={TrendingUp} label="Novos no mês" value={String(stats.novosMes)} color="#2FBF71" />
        <Metric icon={DollarSign} label="MRR" value={brl(stats.mrr)} color="#F47A20" />
        <Metric icon={UserMinus} label="Cancelamentos" value={String(stats.cancelados)} color="#E23B2E" />
        <Metric icon={Gift} label="Resgates" value={String(stats.resgates)} color="#2FBF71" />
      </div>

      <div className="mt-4 grid gap-4 sm:mt-6 sm:gap-6 lg:grid-cols-2">
        <Card>
          <h2 className="mb-4 font-semibold">Receita por mês</h2>
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={stats.receita}>
              <defs>
                <linearGradient id="rev" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#F47A20" stopOpacity={0.4} />
                  <stop offset="95%" stopColor="#F47A20" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" opacity={0.15} />
              <XAxis dataKey="mes" fontSize={11} tickLine={false} axisLine={false} />
              <YAxis fontSize={11} width={44} tickLine={false} axisLine={false} />
              <Tooltip formatter={(v) => brl(Number(v))} />
              <Area type="monotone" dataKey="valor" stroke="#F47A20" fill="url(#rev)" />
            </AreaChart>
          </ResponsiveContainer>
        </Card>

        <Card>
          <h2 className="mb-4 font-semibold">Crescimento de membros</h2>
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={stats.crescimento}>
              <CartesianGrid strokeDasharray="3 3" opacity={0.15} />
              <XAxis dataKey="mes" fontSize={11} tickLine={false} axisLine={false} />
              <YAxis fontSize={11} width={44} tickLine={false} axisLine={false} />
              <Tooltip />
              <Line type="monotone" dataKey="membros" stroke="#2FBF71" strokeWidth={2} dot={false} />
            </LineChart>
          </ResponsiveContainer>
        </Card>
      </div>
    </div>
  );
}
