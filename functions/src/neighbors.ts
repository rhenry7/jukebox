/**
 * User-based collaborative filtering (plan phase 5): lookalike listeners are
 * people who rate the same tracks the same way, or whose overall taste vector
 * is close. Recomputed nightly; small enough to do in memory at this scale.
 */
import { Firestore } from "firebase-admin/firestore";
import { COLLECTIONS, RANKING, seedUserIds } from "./config";
import { toVec } from "./store";
import { cosine, Vec } from "./vectors";

/**
 * Agreement on co-reviewed tracks, in [0, 1]. Affinities are in [-1, 1], so
 * |Δ| / 2 is the disagreement; few shared tracks shrink the score toward 0.
 */
export function ratingAgreement(a: Map<string, number>, b: Map<string, number>): { sim: number; shared: number } {
  let total = 0;
  let shared = 0;
  a.forEach((affA, track) => {
    const affB = b.get(track);
    if (affB === undefined) return;
    total += 1 - Math.abs(affA - affB) / 2;
    shared++;
  });
  if (shared === 0) return { sim: 0, shared: 0 };
  return { sim: (total / shared) * (shared / (shared + 5)), shared };
}

export function blendNeighborSim(agreement: number, tasteCos: number): number {
  return 0.5 * agreement + 0.5 * Math.max(0, tasteCos);
}

/**
 * Each user's most similar listeners. Seed / test accounts (`SEED_USER_IDS`)
 * are never anyone's neighbour: one prolific test account would otherwise be
 * everyone's "listener like you".
 */
export async function computeNeighbors(
  db: Firestore,
  seeds: Set<string> = seedUserIds(),
): Promise<Map<string, { uid: string; sim: number }[]>> {
  const [reviews, users] = await Promise.all([
    db.collection(COLLECTIONS.reviewVectors).select("userId", "trackKey", "affinity").get(),
    db.collection(COLLECTIONS.userVectors).select("centroid").get(),
  ]);

  const ratings = new Map<string, Map<string, number>>();
  reviews.docs.forEach((d) => {
    const uid = d.get("userId") as string;
    const m = ratings.get(uid) ?? new Map<string, number>();
    m.set(d.get("trackKey"), d.get("affinity") ?? 0);
    ratings.set(uid, m);
  });
  const centroids = new Map<string, Vec>();
  users.docs.forEach((d) => {
    const c = toVec(d.get("centroid"));
    if (c.length) centroids.set(d.id, c);
  });

  const uids = [...ratings.keys()].filter((u) => (ratings.get(u)?.size ?? 0) >= 3);
  const out = new Map<string, { uid: string; sim: number }[]>();
  for (const a of uids) {
    const scored: { uid: string; sim: number }[] = [];
    for (const b of uids) {
      if (a === b || seeds.has(b)) continue;
      const { sim: agreement } = ratingAgreement(ratings.get(a)!, ratings.get(b)!);
      const ca = centroids.get(a);
      const cb = centroids.get(b);
      const sim = blendNeighborSim(agreement, ca && cb ? cosine(ca, cb) : 0);
      if (sim > 0) scored.push({ uid: b, sim: Number(sim.toFixed(4)) });
    }
    out.set(
      a,
      scored.sort((x, y) => y.sim - x.sim).slice(0, RANKING.neighbors),
    );
  }
  return out;
}

export async function writeNeighbors(db: Firestore, neighbors: Map<string, { uid: string; sim: number }[]>) {
  const writer = db.bulkWriter();
  neighbors.forEach((list, uid) => {
    writer.set(db.collection(COLLECTIONS.userVectors).doc(uid), { neighbors: list }, { merge: true });
  });
  await writer.close();
}
