import { useEffect, useState } from "react";
import {
  collection,
  onSnapshot,
  query,
  type QueryConstraint,
  type Timestamp,
} from "firebase/firestore";
import { db } from "./firebase";

/** Converte Timestamps do Firestore em Date recursivamente (nível 1). */
function normalize<T>(id: string, data: Record<string, unknown>): T {
  const out: Record<string, unknown> = { id };
  for (const [k, v] of Object.entries(data)) {
    if (v && typeof v === "object" && "toDate" in v) {
      out[k] = (v as Timestamp).toDate();
    } else {
      out[k] = v;
    }
  }
  return out as T;
}

/** Assina uma coleção em tempo real. */
export function useCollection<T>(
  path: string,
  ...constraints: QueryConstraint[]
): { data: T[]; loading: boolean; error: string | null } {
  const [data, setData] = useState<T[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const q = query(collection(db, path), ...constraints);
    const unsub = onSnapshot(
      q,
      (snap) => {
        setData(snap.docs.map((d) => normalize<T>(d.id, d.data())));
        setLoading(false);
      },
      (err) => {
        setError(err.message);
        setLoading(false);
      }
    );
    return unsub;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [path]);

  return { data, loading, error };
}
