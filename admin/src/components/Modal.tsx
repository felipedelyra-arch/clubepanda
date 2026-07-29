import { useEffect } from "react";
import type { ReactNode } from "react";
import { X } from "lucide-react";

export function Modal({
  open,
  onClose,
  title,
  children,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
}) {
  // Esc fecha. Sem isso o único jeito é acertar o X ou o fundo.
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    // Trava a rolagem de trás: no celular o dedo arrastava a página por baixo
    // do formulário em vez de rolar o formulário.
    const overflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = overflow;
    };
  }, [open, onClose]);

  if (!open) return null;
  return (
    // Celular: folha colada embaixo, ao alcance do polegar. Tablet pra cima:
    // caixa centrada de sempre.
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 sm:items-center sm:p-4"
      onClick={onClose}
    >
      <div
        className="flex max-h-[92vh] w-full flex-col rounded-t-[22px] bg-white dark:bg-panda-card-dark sm:max-w-lg sm:rounded-[18px] sm:shadow-xl"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-label={title}
      >
        {/* Cabeçalho fixo: em formulário longo o botão de fechar sumia junto
            com a rolagem. */}
        <div className="flex items-center justify-between border-b border-black/5 px-5 py-4 dark:border-white/10">
          <h2 className="text-lg font-bold">{title}</h2>
          <button
            onClick={onClose}
            aria-label="Fechar"
            className="-mr-2 px-2 text-panda-cinza-texto hover:text-panda-vermelho"
          >
            <X size={20} />
          </button>
        </div>
        <div className="overflow-y-auto px-5 py-4 pb-[calc(1rem+env(safe-area-inset-bottom))] sm:pb-4">
          {children}
        </div>
      </div>
    </div>
  );
}

export function ConfirmDialog({
  open,
  onClose,
  onConfirm,
  title,
  message,
}: {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  message: string;
}) {
  if (!open) return null;
  return (
    <Modal open={open} onClose={onClose} title={title}>
      <p className="mb-6 text-panda-cinza-texto">{message}</p>
      {/* Empilhado no celular, com o destrutivo embaixo do polegar mas em
          vermelho cheio — dá pra ler o que vai acontecer antes de tocar. */}
      <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <button
          onClick={onClose}
          className="min-h-11 rounded-xl px-4 py-2.5 text-sm font-semibold text-panda-cinza-texto hover:bg-black/5 dark:hover:bg-white/5"
        >
          Cancelar
        </button>
        <button
          onClick={() => {
            onConfirm();
            onClose();
          }}
          className="min-h-11 rounded-xl bg-panda-vermelho px-4 py-2.5 text-sm font-semibold text-white hover:opacity-90"
        >
          Confirmar
        </button>
      </div>
    </Modal>
  );
}

const inputBase =
  "w-full min-h-11 rounded-xl bg-panda-cinza dark:bg-panda-superficie-dark px-4 py-2.5 outline-none focus:ring-2 focus:ring-panda-laranja";

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="mb-3 block">
      <span className="mb-1 block text-sm font-medium">{label}</span>
      {children}
    </label>
  );
}

export { inputBase };
