/** Small, dependency-free vector maths. Vectors are plain number arrays. */

export type Vec = number[];

export function dot(a: Vec, b: Vec): number {
  let s = 0;
  for (let i = 0; i < a.length; i++) s += a[i] * b[i];
  return s;
}

export function norm(a: Vec): number {
  return Math.sqrt(dot(a, a));
}

export function normalize(a: Vec): Vec {
  const n = norm(a);
  return n === 0 ? a.slice() : a.map((x) => x / n);
}

export function cosine(a: Vec, b: Vec): number {
  const d = norm(a) * norm(b);
  return d === 0 ? 0 : dot(a, b) / d;
}

/** Weighted mean, normalised. Returns null when there is nothing to average. */
export function weightedCentroid(vectors: Vec[], weights: number[]): Vec | null {
  if (vectors.length === 0) return null;
  const out = new Array<number>(vectors[0].length).fill(0);
  let total = 0;
  vectors.forEach((v, i) => {
    const w = weights[i];
    if (w <= 0) return;
    total += w;
    for (let j = 0; j < v.length; j++) out[j] += v[j] * w;
  });
  return total === 0 ? null : normalize(out);
}

/** Exponential decay: 1.0 today, 0.5 after `halfLifeDays`. */
export function recencyWeight(date: Date | null, halfLifeDays: number, now = new Date()): number {
  if (!date) return 0.5;
  const days = Math.max(0, (now.getTime() - date.getTime()) / 86_400_000);
  return Math.pow(0.5, days / halfLifeDays);
}

export interface Cluster {
  centroid: Vec;
  /** Sum of member weights — how big a part of the user's taste this is. */
  weight: number;
  members: number[];
}

/**
 * Weighted spherical k-means with deterministic farthest-point init, so the
 * same history always yields the same interests.
 */
export function kmeans(vectors: Vec[], weights: number[], k: number, iterations = 10): Cluster[] {
  const n = vectors.length;
  if (n === 0) return [];
  k = Math.max(1, Math.min(k, n));
  const unit = vectors.map(normalize);

  // Init: heaviest point, then repeatedly the point farthest from all centroids.
  let first = 0;
  weights.forEach((w, i) => {
    if (w > weights[first]) first = i;
  });
  const centroids: Vec[] = [unit[first]];
  while (centroids.length < k) {
    let best = -1;
    let bestDist = -1;
    for (let i = 0; i < n; i++) {
      const d = Math.min(...centroids.map((c) => 1 - dot(c, unit[i])));
      if (d > bestDist) {
        bestDist = d;
        best = i;
      }
    }
    if (bestDist <= 1e-9) break; // all remaining points are duplicates
    centroids.push(unit[best]);
  }

  let assign = new Array<number>(n).fill(0);
  for (let it = 0; it < iterations; it++) {
    const next = unit.map((v) => {
      let bi = 0;
      let bs = -Infinity;
      centroids.forEach((c, ci) => {
        const s = dot(c, v);
        if (s > bs) {
          bs = s;
          bi = ci;
        }
      });
      return bi;
    });
    const changed = next.some((a, i) => a !== assign[i]);
    assign = next;
    centroids.forEach((_, ci) => {
      const idx = assign.map((a, i) => (a === ci ? i : -1)).filter((i) => i >= 0);
      const c = weightedCentroid(
        idx.map((i) => unit[i]),
        idx.map((i) => weights[i]),
      );
      if (c) centroids[ci] = c;
    });
    if (!changed && it > 0) break;
  }

  return centroids
    .map((centroid, ci) => {
      const members = assign.map((a, i) => (a === ci ? i : -1)).filter((i) => i >= 0);
      return { centroid, members, weight: members.reduce((s, i) => s + weights[i], 0) };
    })
    .filter((c) => c.members.length > 0)
    .sort((a, b) => b.weight - a.weight);
}
