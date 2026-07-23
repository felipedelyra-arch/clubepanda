import type { ButtonHTMLAttributes, ReactNode } from "react";

export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <div
      className={`rounded-[18px] bg-panda-cinza dark:bg-[#262626] p-5 shadow-sm ${className}`}
    >
      {children}
    </div>
  );
}

type BtnProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "outline" | "danger" | "ghost";
};

export function Button({ variant = "primary", className = "", ...props }: BtnProps) {
  const base =
    "inline-flex items-center justify-center gap-2 rounded-xl px-4 py-2.5 font-semibold text-sm transition disabled:opacity-50 disabled:cursor-not-allowed";
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
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold ${colors[color]}`}>
      {children}
    </span>
  );
}

export function EmptyState({ mensagem }: { mensagem: string }) {
  return (
    <div className="py-16 text-center text-panda-cinza-texto">{mensagem}</div>
  );
}

export function Spinner() {
  return (
    <div className="flex justify-center py-16">
      <div className="h-8 w-8 animate-spin rounded-full border-2 border-panda-laranja border-t-transparent" />
    </div>
  );
}
