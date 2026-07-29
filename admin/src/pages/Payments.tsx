import { useMemo, useState } from "react";
import { Download } from "lucide-react";
import { useCollection } from "../lib/useCollection";
import type { AppUser, Payment } from "../lib/types";
import {
  Card,
  Badge,
  Spinner,
  EmptyState,
  ErrorState,
  PageHeader,
  Button,
} from "../components/ui";
import { brl, dia, metodoLabel } from "../lib/format";

export function Payments() {
  const { data, loading, error } = useCollection<Payment>("payments");
  const { data: users } = useCollection<AppUser>("users");
  const [metodo, setMetodo] = useState<"todos" | "cartao" | "pix">("todos");

  // O documento de pagamento só guarda o uid; o nome vem da coleção de users.
  const nomePorUid = useMemo(() => {
    const m = new Map<string, string>();
    users.forEach((u) => m.set(u.uid, u.nome || u.email || u.uid));
    return m;
  }, [users]);

  const filtrados = useMemo(
    () => data.filter((p) => metodo === "todos" || p.metodo === metodo),
    [data, metodo]
  );

  const total = filtrados.reduce((a, p) => a + (p.status === "aprovado" ? p.valor : 0), 0);

  function exportarCSV() {
    const linhas = [
      ["Cliente", "Valor", "Método", "Status", "Data", "Ref"],
      ...filtrados.map((p) => [
        nomePorUid.get(p.userId) ?? p.userId,
        String(p.valor),
        p.metodo,
        p.status,
        p.data ? p.data.toLocaleString("pt-BR") : "",
        p.gatewayRef ?? "",
      ]),
    ];
    const csv = linhas.map((l) => l.map((c) => `"${c}"`).join(",")).join("\n");
    const blob = new Blob(["﻿" + csv], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `pagamentos_${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  if (loading) return <Spinner />;
  if (error) return <ErrorState mensagem={error} />;

  const nome = (uid: string) => nomePorUid.get(uid) ?? `${uid.slice(0, 10)}…`;

  return (
    <div>
      <PageHeader
        titulo="Pagamentos"
        acao={
          <Button variant="outline" onClick={exportarCSV} disabled={!filtrados.length}>
            <Download size={18} /> Exportar CSV
          </Button>
        }
      />

      {/* O total é o número que o dono veio buscar — sobe pra cima e ganha
          corpo, em vez de ficar de legenda ao lado do filtro. */}
      <Card className="mb-4">
        <div className="text-sm text-panda-cinza-texto">Total aprovado no filtro</div>
        <div className="tabular text-3xl font-bold text-panda-verde">{brl(total)}</div>
        <select
          className="mt-3 min-h-11 w-full rounded-xl bg-white px-4 py-2.5 outline-none dark:bg-panda-card-dark sm:w-auto"
          value={metodo}
          onChange={(e) => setMetodo(e.target.value as typeof metodo)}
        >
          <option value="todos">Todos os métodos</option>
          <option value="cartao">Cartão</option>
          <option value="pix">Pix</option>
        </select>
      </Card>

      {!filtrados.length ? (
        <EmptyState mensagem="Nenhuma cobrança com esse filtro. As cobranças aparecem aqui quando o gateway confirma." />
      ) : (
        <>
          {/* Celular: uma linha por cobrança, com valor e status onde o olho
              cai primeiro. Seis colunas não cabem em 360px. */}
          <div className="flex flex-col gap-2 sm:hidden">
            {filtrados.map((p) => (
              <div key={p.id} className="rounded-2xl bg-panda-cinza p-4 dark:bg-panda-superficie-dark">
                <div className="flex items-start justify-between gap-3">
                  <span className="min-w-0 truncate font-medium">{nome(p.userId)}</span>
                  <span className="tabular shrink-0 font-semibold">{brl(p.valor)}</span>
                </div>
                <div className="mt-2 flex items-center justify-between gap-3">
                  <span className="tabular text-sm text-panda-cinza-texto">
                    {dia(p.data)} · {metodoLabel(p.metodo)}
                  </span>
                  <Badge color={p.status === "aprovado" ? "green" : "red"}>{p.status}</Badge>
                </div>
              </div>
            ))}
          </div>

          <Card className="hidden p-0 sm:block">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-black/5 dark:bg-white/5 text-left text-panda-cinza-texto">
                  <tr>
                    <th className="p-3">Cliente</th><th className="p-3">Valor</th><th className="p-3">Método</th>
                    <th className="p-3">Status</th><th className="p-3">Data</th><th className="p-3">Ref</th>
                  </tr>
                </thead>
                <tbody>
                  {filtrados.map((p) => (
                    <tr key={p.id} className="border-t border-black/5 dark:border-white/5">
                      <td className="p-3 font-medium">{nome(p.userId)}</td>
                      <td className="p-3">{brl(p.valor)}</td>
                      <td className="p-3">{metodoLabel(p.metodo)}</td>
                      <td className="p-3">
                        <Badge color={p.status === "aprovado" ? "green" : "red"}>{p.status}</Badge>
                      </td>
                      <td className="p-3">{dia(p.data)}</td>
                      <td className="p-3 font-mono text-xs">{p.gatewayRef?.slice(0, 14) ?? "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        </>
      )}
    </div>
  );
}
