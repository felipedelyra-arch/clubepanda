import type { ButtonHTMLAttributes, ReactNode } from "react";

export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <div
      className={`rounded-[18px] bg-panda-cinza dark:bg-panda-superficie-dark p-4 shadow-sm sm:p-5 ${className}`}
    >
      {children}
    </div>
  );
}

/**
 * Cabeçalho de página. No celular o título fica em cima e a ação embaixo,
 * ocupando a largura toda — botão de canto é difícil de acertar com o polegar.
 */
export function PageHeader({
  titulo,
  descricao,
  acao,
}: {
  titulo: string;
  descricao?: string;
  acao?: ReactNode;
}) {
  return (
    <div className="mb-5 flex flex-col gap-3 sm:mb-6 sm:flex-row sm:items-start sm:justify-between">
      <div>
        {/* No celular o título já está na barra de cima — repetir aqui só
            empurra o conteúdo pra baixo. */}
        <h1 className="hidden text-xl font-bold sm:block sm:text-2xl">{titulo}</h1>
        {descricao && (
          <p className="text-sm text-panda-cinza-texto sm:mt-1">{descricao}</p>
        )}
      </div>
      {acao && <div className="[&>button]:w-full sm:[&>button]:w-auto">{acao}</div>}
    </div>
  );
}

type BtnProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "outline" | "danger" | "ghost";
};

export function Button({ variant = "primary", className = "", ...props }: BtnProps) {
  const base =
    "inline-flex min-h-11 items-center justify-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold transition active:scale-[0.98] disabled:opacity-50 disabled:cursor-not-allowed disabled:active:scale-100";
  const variants = {
    primary: "bg-panda-laranja text-white hover:bg-panda-laranja-escuro",
    outline:
      "border border-panda-laranja text-panda-laranja hover:bg-panda-laranja/10",
    danger: "bg-panda-vermelho text-white hover:opacity-90",
    ghost: "text-panda-cinza-texto hover:bg-black/5 dark:hover:bg-white/5",
  };
  return <button className={`${base} ${variants[variant]} ${className}`} {...props} />;
}

export function Badge({ children, color = "gray" }: { children: ReactNode; color?: "green" | "orange" | "red" | "gray" }) {
  const colors = {
    green: "bg-panda-verde/15 text-panda-verde",
    orange: "bg-panda-laranja/15 text-panda-laranja",
    red: "bg-panda-vermelho/15 text-panda-vermelho",
    gray: "bg-panda-cinza-texto/15 text-panda-cinza-texto",
  };
  return (
    <span className={`inline-flex shrink-0 items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-semibold ${colors[color]}`}>
      {children}
    </span>
  );
}

/**
 * Ponto de "no ar". Só aparece no que está valendo neste minuto — promoção
 * dentro da janela, plano ativo. É o único elemento animado do painel; se
 * espalhar por outros estados, para de querer dizer alguma coisa.
 */
export function LiveDot() {
  return (
    <span
      aria-hidden
      className="inline-block h-1.5 w-1.5 rounded-full bg-current"
      style={{ animation: "panda-pulso 2s ease-in-out infinite" }}
    />
  );
}

export function EmptyState({ mensagem, acao }: { mensagem: string; acao?: ReactNode }) {
  return (
    <div className="rounded-[18px] border border-dashed border-black/10 dark:border-white/10 px-6 py-12 text-center">
      <p className="text-sm text-panda-cinza-texto">{mensagem}</p>
      {acao && <div className="mt-4 flex justify-center">{acao}</div>}
    </div>
  );
}

/**
 * Falha ao ler o Firestore (permissão, rede, índice faltando). Sem isso a tela
 * fica vazia e parece "não tem nada cadastrado", que é diagnóstico errado.
 */
export function ErrorState({ mensagem }: { mensagem: string }) {
  return (
    <div className="rounded-[18px] border border-panda-vermelho/30 bg-panda-vermelho/10 p-5">
      <div className="font-semibold text-panda-vermelho">
        Não consegui carregar os dados
      </div>
      <p className="mt-1 text-sm text-panda-cinza-texto">{mensagem}</p>
      <button
        onClick={() => window.location.reload()}
        className="mt-3 text-sm font-semibold text-panda-laranja hover:underline"
      >
        Tentar de novo
      </button>
    </div>
  );
}

export function Spinner() {
  return (
    <div className="flex justify-center py-16">
      <div className="h-8 w-8 animate-spin rounded-full border-2 border-panda-laranja border-t-transparent" />
    </div>
  );
}

/** Linha rótulo/valor dos cartões que substituem tabela no celular. */
export function LinhaDado({ rotulo, valor }: { rotulo: string; valor: ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-4 text-sm">
      <span className="shrink-0 text-panda-cinza-texto">{rotulo}</span>
      <span className="text-right tabular">{valor}</span>
    </div>
  );
}
