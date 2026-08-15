import { useMemo, useState } from "react";
import type { ReactNode } from "react";
import { Search } from "lucide-react";
import { useCollection } from "../lib/useCollection";
import { useFichaDoSocio } from "../lib/useFichaDoSocio";
import type { AppUser, Plan, Subscription } from "../lib/types";
import {
  Card,
  Badge,
  Spinner,
  EmptyState,
  ErrorState,
  PageHeader,
} from "../components/ui";
import { Modal } from "../components/Modal";
import { brl, dia, metodoLabel } from "../lib/format";

export function Members() {
  // `users` e `subscriptions` seguem inteiras: a lista É a tela, e o tamanho
  // delas é o número de sócios do clube — cresce com o negócio, não com o
  // tempo. `plans` são três documentos.
  //
  // ⚠️ Quando o clube passar de alguns milhares, esta tela precisa de busca no
  // servidor (campo `nomeBusca` em minúsculas + consulta por prefixo) e
  // paginação. Fica registrado aqui porque o dia em que doer não vai ter aviso.
  const { data: users, loading, error } = useCollection<AppUser>("users");
  const { data: subs } = useCollection<Subscription>("subscriptions");
  const { data: plans } = useCollection<Plan>("plans");
  const [busca, setBusca] = useState("");
  const [aberto, setAberto] = useState<AppUser | null>(null);

  // Cobranças e resgates do sócio só são buscados quando a ficha abre. Antes
  // esta tela baixava as duas coleções INTEIRAS para filtrar em memória as
  // poucas linhas de quem o dono clicou.
  const { pagamentos: pagamentosDele, resgates: resgatesDele } = useFichaDoSocio(
    aberto?.uid ?? null
  );

  const subByUser = useMemo(() => {
    const m = new Map<string, Subscription>();
    // Assinatura ativa ganha. Sem ativa, guarda a cancelada/atrasada — assim a
    // ficha mostra "cancelou" em vez de "nunca assinou".
    subs.forEach((s) => {
      if (s.status === "active" || !m.has(s.userId)) m.set(s.userId, s);
    });
    return m;
  }, [subs]);

  const planoPorId = useMemo(() => {
    const m = new Map<string, Plan>();
    plans.forEach((p) => m.set(p.id, p));
    return m;
  }, [plans]);

  const filtrados = users.filter((u) =>
    [u.nome, u.email, u.telefone].some((v) => v?.toLowerCase().includes(busca.toLowerCase()))
  );

  const sub = aberto ? subByUser.get(aberto.uid) : undefined;
  const plano = sub ? planoPorId.get(sub.planId) : undefined;

  if (loading) return <Spinner />;
  if (error) return <ErrorState mensagem={error} />;

  const selo = (s?: Subscription) =>
    s?.status === "active" ? (
      <Badge color="green">Assinante</Badge>
    ) : s ? (
      <Badge color="red">Cancelou</Badge>
    ) : (
      <Badge color="gray">Free</Badge>
    );

  return (
    <div>
      <PageHeader
        titulo="Membros"
        descricao={`${users.length} cadastrado(s) · toque num nome pra ver a ficha`}
      />
      <div className="mb-4 flex min-h-11 items-center gap-2 rounded-xl bg-panda-cinza px-4 py-2.5 dark:bg-panda-superficie-dark sm:max-w-md">
        <Search size={18} className="shrink-0 text-panda-cinza-texto" />
        <input className="w-full bg-transparent outline-none" placeholder="Buscar por nome, e-mail, telefone" value={busca} onChange={(e) => setBusca(e.target.value)} />
      </div>

      {!filtrados.length ? (
        <EmptyState mensagem={busca ? "Ninguém com esse nome, e-mail ou telefone." : "Ninguém se cadastrou ainda. Os membros aparecem aqui assim que criam a conta no app."} />
      ) : (
        <>
          {/* Celular: cartão por pessoa. A tabela de 5 colunas obrigava a
              arrastar de lado, que é onde o dono desistia. */}
          <div className="flex flex-col gap-2 sm:hidden">
            {filtrados.map((u) => (
              <button
                key={u.uid}
                onClick={() => setAberto(u)}
                className="flex w-full items-center justify-between gap-3 rounded-2xl bg-panda-cinza p-4 text-left dark:bg-panda-superficie-dark"
              >
                <div className="min-w-0">
                  <div className="truncate font-medium">{u.nome || "Sem nome"}</div>
                  <div className="truncate text-sm text-panda-cinza-texto">{u.email}</div>
                </div>
                {selo(subByUser.get(u.uid))}
              </button>
            ))}
          </div>

          <Card className="hidden p-0 sm:block">
            <table className="w-full text-sm">
              <thead className="bg-black/5 dark:bg-white/5 text-left text-panda-cinza-texto">
                <tr>
                  <th className="p-3">Nome</th><th className="p-3">E-mail</th><th className="p-3">Telefone</th>
                  <th className="p-3">Entrou em</th><th className="p-3">Status</th>
                </tr>
              </thead>
              <tbody>
                {filtrados.map((u) => (
                  <tr
                    key={u.uid}
                    onClick={() => setAberto(u)}
                    className="cursor-pointer border-t border-black/5 dark:border-white/5 hover:bg-black/5 dark:hover:bg-white/5"
                  >
                    <td className="p-3 font-medium">{u.nome || "—"}</td>
                    <td className="p-3">{u.email}</td>
                    <td className="p-3">{u.telefone || "—"}</td>
                    <td className="p-3">{dia(u.criadoEm)}</td>
                    <td className="p-3">{selo(subByUser.get(u.uid))}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Card>
        </>
      )}

      <Modal
        open={!!aberto}
        onClose={() => setAberto(null)}
        title={aberto?.nome || aberto?.email || "Membro"}
      >
        {aberto && (
          <div className="space-y-5 text-sm">
            <div className="space-y-1">
              <Linha rotulo="E-mail" valor={aberto.email} />
              <Linha rotulo="Telefone" valor={aberto.telefone || "—"} />
              <Linha rotulo="Entrou em" valor={dia(aberto.criadoEm)} />
              <Linha rotulo="UID" valor={<span className="font-mono text-xs">{aberto.uid}</span>} />
            </div>

            <Secao titulo="Assinatura">
              {!sub ? (
                <p className="text-panda-cinza-texto">Nunca assinou.</p>
              ) : (
                <div className="space-y-1">
                  <Linha rotulo="Plano" valor={plano ? `${plano.nome} — ${brl(plano.preco)}` : sub.planId} />
                  <Linha
                    rotulo="Status"
                    valor={
                      sub.status === "active" ? <Badge color="green">ativa</Badge>
                      : sub.status === "canceled" ? <Badge color="red">cancelada</Badge>
                      : <Badge color="orange">em atraso</Badge>
                    }
                  />
                  <Linha rotulo="Próxima cobrança" valor={dia(sub.proximaCobranca)} />
                  <Linha rotulo="Forma de pagamento" valor={metodoLabel(sub.formaPagamento)} />
                </div>
              )}
            </Secao>

            <Secao titulo={`Pagamentos (${pagamentosDele.length})`}>
              {!pagamentosDele.length ? (
                <p className="text-panda-cinza-texto">Nenhum pagamento registrado.</p>
              ) : (
                <ul className="space-y-1.5">
                  {pagamentosDele.map((p) => (
                    <li key={p.id} className="flex items-center justify-between gap-3">
                      <span className="text-panda-cinza-texto">{dia(p.data)} · {metodoLabel(p.metodo)}</span>
                      <span className="flex items-center gap-2">
                        {brl(p.valor)}
                        <Badge color={p.status === "aprovado" ? "green" : "red"}>{p.status}</Badge>
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </Secao>

            <Secao titulo={`Resgates (${resgatesDele.length})`}>
              {!resgatesDele.length ? (
                <p className="text-panda-cinza-texto">Nenhum prêmio resgatado.</p>
              ) : (
                <ul className="space-y-1.5">
                  {resgatesDele.map((r) => (
                    <li key={r.id} className="flex items-center justify-between gap-3">
                      <span>
                        <span className="text-panda-cinza-texto">{dia(r.criadoEm)} · </span>
                        {r.rewardTitulo}
                      </span>
                      <Badge color={r.status === "disponivel" ? "orange" : r.status === "usado" ? "green" : "gray"}>
                        {r.status}
                      </Badge>
                    </li>
                  ))}
                </ul>
              )}
            </Secao>
          </div>
        )}
      </Modal>
    </div>
  );
}

function Linha({ rotulo, valor }: { rotulo: string; valor: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-4">
      <span className="text-panda-cinza-texto">{rotulo}</span>
      <span className="text-right">{valor}</span>
    </div>
  );
}

function Secao({ titulo, children }: { titulo: string; children: ReactNode }) {
  return (
    <div>
      <h3 className="mb-2 border-t border-black/5 dark:border-white/10 pt-4 font-semibold">
        {titulo}
      </h3>
      {children}
    </div>
  );
}
