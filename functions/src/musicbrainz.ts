/**
 * MusicBrainz IDs on reviews, and similar artists from ListenBrainz.
 *
 * Each review gets `recordingMbid` / `artistMbids` (the song and artists'
 * MusicBrainz IDs) when written, so suggestions can use ListenBrainz's
 * listening-based similarity. Similar artists are cached per artist in
 * `similarArtists/{artistMbid}` (public read, server write), which the app
 * reads for "More like this" and onboarding, and For You reads here.
 *
 * Both services are free and need no key. MusicBrainz allows about one
 * request a second, so calls go through one queue.
 */
import { FieldValue, Firestore, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { trackKey } from "./text";

const MB_BASE = "https://musicbrainz.org/ws/2";
const USER_AGENT = "REVERB/1.0 ( https://juxeboxd.web.app )";

/**
 * ListenBrainz's similar-artists dataset. It lives on their "labs" server and
 * the name may change; if it does, calls fail and cached lists stay in use.
 */
export const SIMILAR_ARTISTS_URL = "https://labs.api.listenbrainz.org/similar-artists/json";
export const SIMILAR_ARTISTS_ALGORITHM =
  "session_based_days_7500_session_300_contribution_5_threshold_10_limit_100_filter_True_skip_30";

export const SIMILAR_ARTISTS_COLLECTION = "similarArtists";
/** How many similar artists are kept per artist. */
export const SIMILAR_ARTISTS_KEEP = 50;
/** Cached similar artists are refreshed after this long. */
const SIMILAR_ARTISTS_MAX_AGE_MS = 30 * 86_400_000;
/** A MusicBrainz search result below this score (0–100) isn't trusted. */
const MIN_MATCH_SCORE = 90;

export interface MbIds {
  recordingMbid: string | null;
  artistMbids: string[];
}

export interface SimilarArtist {
  mbid: string;
  name: string;
  /** 0–1, relative to the most similar artist. */
  score: number;
}

// ── Pure parsing (unit-tested) ─────────────────────────────────────────────

/** Lowercase, no accents or punctuation, single spaces: for comparing names. */
export function normName(s: string): string {
  return s
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

/** The review's artists: "Masego, FKJ" → ["masego", "fkj"]. */
export function reviewArtists(artist: string): string[] {
  return artist
    .split(/,|\bfeat\.?|\bft\.?/i)
    .map(normName)
    .filter((a) => a.length > 0);
}

interface MbRecording {
  id: string;
  score?: number;
  title?: string;
  "artist-credit"?: { name?: string; artist?: { id?: string; name?: string } }[];
}

/**
 * The search result that is this review's song: a confident match (score
 * ≥ 90) credited to one of the review's artists, preferring an exact title.
 * Returns its ID and every credited artist's ID; null if none fits.
 */
export function pickRecording(results: MbRecording[], title: string, artist: string): MbIds | null {
  const wanted = new Set(reviewArtists(artist));
  const wantedTitle = normName(title);
  const fits = results.filter((r) => {
    if ((r.score ?? 0) < MIN_MATCH_SCORE) return false;
    const credits = r["artist-credit"] ?? [];
    return credits.some((c) => wanted.has(normName(c.artist?.name ?? c.name ?? "")));
  });
  const best = fits.find((r) => normName(r.title ?? "") === wantedTitle) ?? fits[0];
  if (!best) return null;
  const artistMbids = [
    ...new Set((best["artist-credit"] ?? []).map((c) => c.artist?.id).filter((id): id is string => !!id)),
  ];
  return { recordingMbid: best.id, artistMbids };
}

interface MbArtist {
  id: string;
  score?: number;
  name?: string;
}

/** An exact-name, confident artist match's ID, or null. */
export function pickArtist(results: MbArtist[], name: string): string | null {
  const wanted = normName(name);
  return results.find((a) => (a.score ?? 0) >= MIN_MATCH_SCORE && normName(a.name ?? "") === wanted)?.id ?? null;
}

/**
 * ListenBrainz's similar-artists rows for one artist, best first, with scores
 * scaled so the best is 1. The response is a list (sometimes nested).
 */
export function parseSimilarArtists(body: unknown, keep = SIMILAR_ARTISTS_KEEP): SimilarArtist[] {
  const rows: { artist_mbid?: string; name?: string; score?: number }[] = [];
  const walk = (x: unknown) => {
    if (Array.isArray(x)) x.forEach(walk);
    else if (x && typeof x === "object" && "artist_mbid" in x) rows.push(x as (typeof rows)[number]);
  };
  walk(body);
  const valid = rows
    .filter((r) => typeof r.artist_mbid === "string" && typeof r.name === "string")
    .sort((a, b) => (b.score ?? 0) - (a.score ?? 0))
    .slice(0, keep);
  const top = Math.max(1, valid[0]?.score ?? 1);
  return valid.map((r) => ({
    mbid: r.artist_mbid!,
    name: r.name!,
    score: Number(((r.score ?? 0) / top).toFixed(3)),
  }));
}

// ── Network ────────────────────────────────────────────────────────────────

let queue: Promise<unknown> = Promise.resolve();
let lastCall = 0;

/** Attempts per MusicBrainz call when it answers 503 ("slow down / busy"). */
const MB_ATTEMPTS = 4;

/** How long to wait before retry [attempt] (1-based): Retry-After if given, else 2, 4, 8 s. */
export function retryDelayMs(attempt: number, retryAfter: string | null): number {
  const seconds = Number(retryAfter);
  if (Number.isFinite(seconds) && seconds > 0) return Math.min(seconds, 30) * 1000;
  return 2000 * 2 ** (attempt - 1);
}

/**
 * GETs JSON, one MusicBrainz call at a time, ≥1.1 s apart. MusicBrainz
 * answers 503 when it's busy or we're too fast: wait and try again.
 */
function mbGet(path: string, params: Record<string, string>): Promise<unknown> {
  const run = async () => {
    const url = `${MB_BASE}/${path}?${new URLSearchParams({ ...params, fmt: "json" })}`;
    for (let attempt = 1; ; attempt++) {
      const wait = 1100 - (Date.now() - lastCall);
      if (wait > 0) await new Promise((r) => setTimeout(r, wait));
      lastCall = Date.now();
      const res = await fetch(url, { headers: { "User-Agent": USER_AGENT }, signal: AbortSignal.timeout(15_000) });
      if (res.ok) return res.json();
      if (res.status !== 503 || attempt >= MB_ATTEMPTS) throw new Error(`MusicBrainz ${path} ${res.status}`);
      await new Promise((r) => setTimeout(r, retryDelayMs(attempt, res.headers.get("retry-after"))));
    }
  };
  const next = queue.then(run, run);
  queue = next.catch(() => undefined);
  return next;
}

const quote = (s: string) => s.replace(/["\\]/g, " ");

/** The song's IDs; falls back to just the main artist's ID if the song isn't found. */
export async function lookupMbIds(title: string, artist: string): Promise<MbIds | null> {
  const mainArtist = artist.split(",")[0].trim();
  if (!title.trim() || !mainArtist) return null;
  const search = (await mbGet("recording", {
    query: `recording:"${quote(title)}" AND artist:"${quote(mainArtist)}"`,
    limit: "10",
  })) as { recordings?: MbRecording[] };
  const found = pickRecording(search.recordings ?? [], title, artist);
  if (found) return found;
  const artists = (await mbGet("artist", { query: `artist:"${quote(mainArtist)}"`, limit: "5" })) as {
    artists?: MbArtist[];
  };
  const id = pickArtist(artists.artists ?? [], mainArtist);
  return id ? { recordingMbid: null, artistMbids: [id] } : null;
}

export async function fetchSimilarArtists(artistMbid: string): Promise<SimilarArtist[]> {
  const url = `${SIMILAR_ARTISTS_URL}?${new URLSearchParams({
    artist_mbids: artistMbid,
    algorithm: SIMILAR_ARTISTS_ALGORITHM,
  })}`;
  const res = await fetch(url, { headers: { "User-Agent": USER_AGENT }, signal: AbortSignal.timeout(15_000) });
  if (!res.ok) throw new Error(`ListenBrainz similar artists ${res.status}`);
  return parseSimilarArtists(await res.json());
}

// ── Firestore ──────────────────────────────────────────────────────────────

/**
 * Writes the review's MusicBrainz IDs if its song changed since they were
 * last looked up (`mbKey`). A song that isn't found is stored as no IDs, so
 * it isn't searched again until the title or artist changes. "failed" (the
 * service couldn't be reached) leaves the review alone to retry next time.
 */
export async function syncMbIds(
  db: Firestore,
  reviewPath: string,
  opts: { dryRun?: boolean } = {},
): Promise<"updated" | "unchanged" | "missing" | "failed"> {
  const ref = db.doc(reviewPath);
  const snap = await ref.get();
  if (!snap.exists) return "missing";
  const data = snap.data() ?? {};
  if (data.isRepost) return "unchanged";
  const key = trackKey(String(data.artist ?? ""), String(data.title ?? ""));
  if (data.mbKey === key) return "unchanged";
  let ids: MbIds | null;
  try {
    ids = await lookupMbIds(String(data.title ?? ""), String(data.artist ?? ""));
  } catch (e) {
    logger.warn("MusicBrainz lookup failed", { reviewPath, error: String(e) });
    return "failed";
  }
  if (!opts.dryRun) {
    await ref.update({
      recordingMbid: ids?.recordingMbid ?? null,
      artistMbids: ids?.artistMbids ?? [],
      mbKey: key,
    });
  }
  return "updated";
}

/** Fetches and caches similar artists for any of [artistMbids] not cached recently. */
export async function ensureSimilarArtists(db: Firestore, artistMbids: string[]): Promise<number> {
  let fetched = 0;
  for (const mbid of artistMbids) {
    const ref = db.collection(SIMILAR_ARTISTS_COLLECTION).doc(mbid);
    const cached = await ref.get();
    const at = (cached.get("fetchedAt") as Timestamp | undefined)?.toMillis() ?? 0;
    if (cached.exists && Date.now() - at < SIMILAR_ARTISTS_MAX_AGE_MS) continue;
    try {
      const similar = await fetchSimilarArtists(mbid);
      await ref.set({ similar, fetchedAt: FieldValue.serverTimestamp() });
      fetched++;
    } catch (e) {
      // Keep any older list; try again next time.
      logger.warn("Similar artists fetch failed", { mbid, error: String(e) });
    }
  }
  return fetched;
}

/** Cached similar artists for each of [artistMbids] (missing ones left out). */
export async function similarArtistsFor(db: Firestore, artistMbids: string[]): Promise<Map<string, SimilarArtist[]>> {
  const out = new Map<string, SimilarArtist[]>();
  if (artistMbids.length === 0) return out;
  const snaps = await db.getAll(...artistMbids.map((id) => db.collection(SIMILAR_ARTISTS_COLLECTION).doc(id)));
  snaps.forEach((s) => s.exists && out.set(s.id, (s.get("similar") as SimilarArtist[]) ?? []));
  return out;
}
