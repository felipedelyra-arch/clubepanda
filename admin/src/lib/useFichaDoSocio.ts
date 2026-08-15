import { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  orderBy,
  limit,
  getDocs,
  type Timestamp,
} from "firebase/firestore";
import { db } from "./firebase";
import { IS_DEMO, demoData } from "./demo";
import type { Payment, Redemption } from "./types";

/** Quantas linhas de histórico a ficha mostra. */
const TETO = 50;

/**
 * Histórico de um sócio: cobranças e resgates, carregados quando a ficha abre.
 *
 * A tela de Membros assinava `payments` e `redemptions` INTEIRAS só para
 * filtrar, em memória, as linhas de quem o dono clicou. Baixava 10.000 contas
 * de salão para exibir as 6 de uma pessoa — e `payments` cresce a cada conta
 * fechada, para sempre.
 *
 * Agora a consulta é por `userId`, com teto, e só acontece quando alguém
 * realmente abre uma ficha. Fechar a tela sem clicar em ninguém passa a custar
 * zero.
 */
export function useFichaDoSocio(uid: string | null) {
  const [pagamentos, setPagamentos] = useState<Payment[]>([]);
  const [resgates, setResgates] = useState<Redemption[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!uid) {
      setPagamentos([]);
      setResgates([]);
      return;
    }

    if (IS_DEMO) {
      setPagamentos(
        ((demoData["payments"] ?? []) as Payment[]).filter((p) => p.userId === uid)
      );
      setResgates(
        ((demoData["redemptions"] ?? []) as Redemption[]).filter((r) => r.userId === uid)
      );
      return;
    }

    let cancelado = false;
    setLoading(true);

    const paraDate = (v: unknown) =>
      v && typeof v === "object" && "toDate" in v
        ? (v as Timestamp).toDate()
        : (v as Date | undefined);

    (async () => {
      try {
        const [pg, rs] = await Promise.all([
          getDocs(
            query(
              collection(db, "payments"),
              where("userId", "==", uid),
              orderBy("data", "desc"),
              limit(TETO)
            )
          ),
          getDocs(
            query(
              collection(db, "redemptions"),
              where("userId", "==", uid),
              orderBy("criadoEm", "desc"),
              limit(TETO)
            )
          ),
        ]);
        if (cancelado) return;
        setPagamentos(
          pg.docs.map((d) => ({ id: d.id, ...d.data(), data: paraDate(d.get("data")) }) as Payment)
        );
        setResgates(
          rs.docs.map(
            (d) => ({ id: d.id, ...d.data(), criadoEm: paraDate(d.get("criadoEm")) }) as Redemption
          )
        );
      } finally {
        if (!cancelado) setLoading(false);
      }
    })();

    return () => {
      cancelado = true;
    };
  }, [uid]);

  return { pagamentos, resgates, loading };
}
