import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import { db } from "./lib/admin";

/**
 * Faxina dos contadores de limite de chamada (`rateLimits`).
 *
 * Cada janela vira um documento novo (ver `lib/rateLimit.ts`), então a coleção
 * cresce com o uso e nada a limpa. O documento velho é inofensivo — a janela
 * dele já passou e ninguém mais consulta —, mas ocupa armazenamento pra sempre.
 *
 * O ideal é a política de TTL nativa do Firestore no campo `expiraEm`, que
 * apaga sozinho e não custa operação de escrita:
 *
 *   gcloud firestore fields ttls update expiraEm \
 *     --collection-group=rateLimits --enable-ttl --project=<projeto>
 *
 * Esta função é a rede pra enquanto o TTL não estiver configurado, e é barata:
 * quando o TTL estiver ligado ela não acha nada e sai na primeira volta.
 */
export const limparRateLimits = onSchedule(
  { schedule: "every 24 hours", timeZone: "America/Sao_Paulo" },
  async () => {
    const agora = new Date();
    let apagados = 0;

    // Teto por execução, mesmo desenho de `limparAvisosAntigos`: vale mais
    // terminar dentro do tempo do que ser cortado no meio de um lote.
    for (let volta = 0; volta < 20; volta++) {
      const velhos = await db
        .collection("rateLimits")
        .where("expiraEm", "<", agora)
        .limit(450)
        .get();
      if (velhos.empty) break;

      const lote = db.batch();
      velhos.docs.forEach((d) => lote.delete(d.ref));
      await lote.commit();
      apagados += velhos.size;

      if (velhos.size < 450) break;
    }

    if (apagados) logger.info("Faxina dos contadores de limite.", { apagados });
  }
);
