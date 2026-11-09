/**
 * How related two reviews' music is, for evaluation and ranking. Pure
 * functions only (unit-tested).
 *
 * Tag overlap is weighted by rarity (IDF): sharing "darkwave" says much more
 * than sharing "rock", which a large share of reviews carry.
 */
import { normalizeTag } from "./text";

/** What relevance needs to know about a review. */
export interface ItemInfo {
  trackKey: string;
  artist: string;
  artistMbids: string[];
  /** The author's tags plus any filled-in MusicBrainz tags. */
  tags: string[];
}

/** Artist MBID → (similar artist MBID → 0–1 similarity), from `similarArtists`. */
export type SimilarArtistIndex = Map<string, Map<string, number>>;

export type TagIdf = Map<string, number>;

/** Normalized, de-duplicated tag keys. */
export function tagKeys(tags: string[]): string[] {
  return [...new Set(tags.map(normalizeTag).filter((t) => t.length > 0))];
}

/**
 * Inverse document frequency per normalized tag over [docs] (each a review's
 * tags): ln(N / df). A tag on every review scores 0; unseen tags get the
 * maximum (as if seen once).
 */
export function tagIdf(docs: string[][]): TagIdf {
  const df = new Map<string, number>();
  for (const tags of docs) for (const t of tagKeys(tags)) df.set(t, (df.get(t) ?? 0) + 1);
  const n = Math.max(1, docs.length);
  const idf: TagIdf = new Map();
  df.forEach((count, t) => idf.set(t, Math.log(n / count)));
  idf.set("", Math.log(n)); // the "unseen" weight, read by idfOf
  return idf;
}

function idfOf(idf: TagIdf, tag: string): number {
  return idf.get(tag) ?? idf.get("") ?? 1;
}

/** Rarity-weighted Jaccard of two tag lists, in [0, 1]. */
export function idfOverlap(a: string[], b: string[], idf: TagIdf): number {
  const A = new Set(tagKeys(a));
  const B = new Set(tagKeys(b));
  if (A.size === 0 || B.size === 0) return 0;
  let shared = 0;
  let union = 0;
  new Set([...A, ...B]).forEach((t) => {
    const w = idfOf(idf, t);
    union += w;
    if (A.has(t) && B.has(t)) shared += w;
  });
  return union === 0 ? 0 : shared / union;
}

/** Lowercase main artist names ("Masego, FKJ" → ["masego", "fkj"]). */
function artistNames(artist: string): string[] {
  return artist
    .split(",")
    .map((a) => a.trim().toLowerCase())
    .filter(Boolean);
}

export function sameArtist(a: ItemInfo, b: ItemInfo): boolean {
  if (a.artistMbids.some((id) => b.artistMbids.includes(id))) return true;
  const names = new Set(artistNames(a.artist));
  return artistNames(b.artist).some((n) => names.has(n));
}

/** 0–1: how similar [a]'s artists sound to [b]'s, by ListenBrainz (either direction). */
export function artistSimilarity(a: ItemInfo, b: ItemInfo, similar: SimilarArtistIndex): number {
  let best = 0;
  for (const x of a.artistMbids) {
    for (const y of b.artistMbids) {
      best = Math.max(best, similar.get(x)?.get(y) ?? 0, similar.get(y)?.get(x) ?? 0);
    }
  }
  return best;
}

/** Gains used by [gradedGain]. */
export const GAIN = {
  sameTrack: 1,
  sameArtist: 0.6,
  /** × ListenBrainz similarity (0–1). */
  similarArtist: 0.5,
  /** × rarity-weighted tag overlap (0–1). */
  tags: 0.3,
} as const;

/**
 * How good a recommendation [rec] is for someone who loved [target]: the
 * same song counts fully, the same artist 0.6, a similar-sounding artist up
 * to 0.5, shared rare tags up to 0.3. The strongest one counts.
 */
export function gradedGain(rec: ItemInfo, target: ItemInfo, similar: SimilarArtistIndex, idf: TagIdf): number {
  if (rec.trackKey === target.trackKey) return GAIN.sameTrack;
  if (sameArtist(rec, target)) return GAIN.sameArtist;
  return Math.max(
    GAIN.similarArtist * artistSimilarity(rec, target, similar),
    GAIN.tags * idfOverlap(rec.tags, target.tags, idf),
  );
}

/** Strict gain: only the same song (1) or artist (0.6) count. Not tied to any of our data sources. */
export function strictGain(rec: ItemInfo, target: ItemInfo): number {
  if (rec.trackKey === target.trackKey) return GAIN.sameTrack;
  return sameArtist(rec, target) ? GAIN.sameArtist : 0;
}

/**
 * DCG of a ranked list's gains, capped at 1 (one perfect item at rank 1).
 * "hit" is whether any item scored at least [hitAt].
 */
export function dcgAtK(gains: number[], k: number, hitAt = 0.5): { dcg: number; hit: number } {
  const top = gains.slice(0, k);
  const dcg = top.reduce((s, g, i) => s + g / Math.log2(i + 2), 0);
  return { dcg: Math.min(1, dcg), hit: top.some((g) => g >= hitAt) ? 1 : 0 };
}
