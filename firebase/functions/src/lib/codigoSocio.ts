import { FieldValue } from "firebase-admin/firestore";
import { db } from "./admin";

/**
 * Código curto da carteirinha — o que o atendente lê (ou digita) no PDV pra
 * amarrar a conta da mesa ao sócio.
 *
 * Não usa o uid do Firebase de propósito: 28 caracteres aleatórios ninguém
 * digita quando o leitor de QR falha, e é justamente aí que o código precisa
 * funcionar.
 */

/**
 * Sem 0/O, 1/I/L, 5/S, U/V — os pares que o atendente troca lendo do celular
 * do cliente às pressas, no meio do salão.
 */
const ALFABETO = "2346789ABCDEFGHJKMNPQRTWXYZ";
const TAMANHO = 6;

function candidato(): string {
  let s = "";
  for (let i = 0; i < TAMANHO; i++) {
    s += ALFABETO[Math.floor(Math.random() * ALFABETO.length)];
  }
  return s;
}

/**
 * Devolve o código do sócio, criando na primeira vez. Idempotente: chamar duas
 * vezes pro mesmo uid devolve o mesmo código.
 *
 * A unicidade vem da coleção `socioCodes/{codigo} -> uid`, mesmo desenho do
 * `referralCodes`: o doc id é o próprio código, então a colisão é impossível
 * dentro da transação — e o PDV resolve o sócio com uma leitura direta, sem
 * query nem índice.
 */
export async function garantirCodigoSocio(uid: string): Promise<string> {
  const userRef = db.doc(`users/${uid}`);

  for (let i = 0; i < 5; i++) {
    const cand = candidato();
    const lookupRef = db.doc(`socioCodes/${cand}`);

    const code = await db.runTransaction(async (tx) => {
      const [userSnap, existe] = await Promise.all([
        tx.get(userRef),
        tx.get(lookupRef),
      ]);

      const jaTem = userSnap.get("codigoSocio") as string | undefined;
      if (jaTem) return jaTem;
      if (existe.exists) return null; // colidiu, tenta outro

      tx.set(lookupRef, { uid, criadoEm: FieldValue.serverTimestamp() });
      tx.set(userRef, { codigoSocio: cand }, { merge: true });
      return cand;
    });

    if (code) return code;
  }

  throw new Error(`Não deu pra gerar codigoSocio para ${uid}.`);
}
