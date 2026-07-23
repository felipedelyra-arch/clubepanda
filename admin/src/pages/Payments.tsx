import { useMemo, useState } from "react";
import { Download } from "lucide-react";
import { useCollection } from "../lib/useCollection";
import type { Payment } from "../lib/types";
import { Card, Badge, Spinner } from "../components/ui";
import { Button } from "../components/ui";

export function Payments() {
  const { data, loading } = useCollection<Payment>("payments");
  const [metodo, setMetodo] = useState<"todos" | "cartao" | "pix">("todos");

  const filtrados = useMemo(
    () => data.filter((p) => metodo === "todos" || p.metodo === metodo),
    [data, metodo]
  );

  const total = filtrados.reduce((a, p) => a + (p.status === "aprovado" ? p.valor : 0), 0);
  const brl = (v: number) => v.toLocaleString("pt-BR", { style: "currency", currency: "BRL" });

  function exportarCSV() {
    const linhas = [
      ["Cliente", "Valor", "Método", "Status", "Data", "Ref"],
      ...filtrados.map((p) => [
        p.userId,
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

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold">Pagamentos</h1>
        <Button variant="outline" onClick={exportarCSV}><Download size={18} /> Exportar CSV</Button>
      </div>

      <div className="mb-4 flex items-center gap-3">
        <select className="rounded-xl bg-panda-cinza dark:bg-[#262626] px-4 py-2.5 outline-none" value={metodo} onChange={(e) => setMetodo(e.target.value as typeof metodo)}>
          <option value="todos">Todos os métodos</option>
          <option value="cartao">Cartão</option>
          <option value="pix">Pix</option>
        </select>
        <span className="text-panda-cinza-texto">Total aprovado: <strong className="text-panda-verde">{brl(total)}</strong></span>
      </div>

      <Card className="p-0 overflow-x-auto">
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
                <td className="p-3 font-mono text-xs">{p.userId.slice(0, 10)}…</td>
                <td className="p-3">{brl(p.valor)}</td>
                <td className="p-3 capitalize">{p.metodo}</td>
                <td className="p-3">
                  <Badge color={p.status === "aprovado" ? "green" : "red"}>{p.status}</Badge>
                </td>
                <td className="p-3">{p.data ? p.data.toLocaleDateString("pt-BR") : "—"}</td>
                <td className="p-3 font-mono text-xs">{p.gatewayRef?.slice(0, 14) ?? "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  );
}
