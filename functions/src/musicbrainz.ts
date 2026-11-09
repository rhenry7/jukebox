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
import { COLLECTIONS } from "./config";
import { metaTagsFor, yearFrom } from "./era";
import { normalizeTag, reviewDocId, trackKey } from "./text";

const MB_BASE = "https://musicbrainz.org/ws/2";
const USER_AGENT = "REVERB/1.0 ( https://juxeboxd.web.app )";

/**
 * ListenBrainz's similar-artists dataset. It lives on their "labs" server and
 * the name may change; if it does, calls fail and cached lists stay in use.
 */
export const SIMILAR_ARTISTS_URL = "https://labs.api.listenbrainz.org/similar-artists/json";
export const SIMILAR_ARTISTS_ALGORITHM =
  "session_based_days_7500_session_300_contribution_5_threshold_10_limit_100_filter_True_skip_30";

/** ListenBrainz's similar-recordings dataset (labs server, like similar artists). */
export const SIMILAR_RECORDINGS_URL = "https://labs.api.listenbrainz.org/similar-recordings/json";
export const SIMILAR_RECORDINGS_ALGORITHM =
  "session_based_days_9000_session_300_contribution_5_threshold_15_limit_50_skip_30";
export const SIMILAR_RECORDINGS_COLLECTION = "similarRecordings";

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
  /** The song's first release year (earliest of its matching recordings). */
  releaseYear?: number | null;
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
  "first-release-date"?: string;
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
  // A song often has several recordings (remasters, singles, album cuts):
  // its era is the earliest release among same-titled matches.
  const sameTitle = fits.filter((r) => normName(r.title ?? "") === normName(best.title ?? ""));
  const years = sameTitle.map((r) => yearFrom(r["first-release-date"])).filter((y): y is number => y !== null);
  return { recordingMbid: best.id, artistMbids, releaseYear: years.length ? Math.min(...years) : null };
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

/**
 * Whether a free-form tag is worth using: not personal or bookkeeping
 * ("seen live", "meme", "favorites"), not a bare year, a sensible length.
 * Same rule as `isUsefulTag` in lib/services/tag_suggestion_service.dart.
 */
export function isUsefulTag(tag: string): boolean {
  const t = normalizeTag(tag);
  if (t.length < 2 || t.length > 30) return false;
  if (/^\d+$/.test(t)) return false;
  const junk = [
    "meme", "seen live", "favorite", "favourite", "owned", "spotify", "playlist",
    "listened", "to listen", "fixme", "check", "wishlist", "my ", "love it",
  ];
  return !junk.some((j) => t.includes(j));
}

/** How many filled-in tags a review keeps. */
export const MB_TAGS_KEEP = 6;
/** A free-form (non-genre) tag needs this many votes to count. */
const MIN_FREEFORM_VOTES = 3;

interface LbTag {
  tag?: string;
  count?: number;
  genre_mbid?: string;
  artist_mbid?: string;
}

/**
 * Filled-in tags from ListenBrainz metadata for one song: its own genres,
 * then its album's, then its artists', most voted first. Official genres
 * (with a `genre_mbid`) always count; free-form tags only with
 * ≥`MIN_FREEFORM_VOTES` votes and passing [isUsefulTag]. Lowercase,
 * de-duplicated by `normalizeTag`, at most [keep].
 */
export function pickMbTags(
  tags: { recording?: LbTag[]; release_group?: LbTag[]; artist?: LbTag[] } | undefined,
  keep = MB_TAGS_KEEP,
): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  for (const level of [tags?.recording, tags?.release_group, tags?.artist]) {
    const ranked = [...(level ?? [])]
      .filter((t) => typeof t.tag === "string")
      .filter((t) => t.genre_mbid || ((t.count ?? 0) >= MIN_FREEFORM_VOTES && isUsefulTag(t.tag!)))
      .sort((a, b) => Number(!!b.genre_mbid) - Number(!!a.genre_mbid) || (b.count ?? 0) - (a.count ?? 0));
    for (const t of ranked) {
      const key = normalizeTag(t.tag!);
      if (!key || seen.has(key)) continue;
      seen.add(key);
      out.push(t.tag!.trim().toLowerCase());
      if (out.length === keep) return out;
    }
  }
  return out;
}

export interface SimilarRecording {
  mbid: string;
  title: string;
  artist: string;
  /** 0–1, relative to the most similar song. */
  score: number;
}

/** ListenBrainz's similar-recordings rows, best first, scores scaled so the best is 1. */
export function parseSimilarRecordings(body: unknown, keep = SIMILAR_ARTISTS_KEEP): SimilarRecording[] {
  const rows: { recording_mbid?: string; recording_name?: string; artist_credit_name?: string; score?: number }[] = [];
  const walk = (x: unknown) => {
    if (Array.isArray(x)) x.forEach(walk);
    else if (x && typeof x === "object" && "recording_mbid" in x) rows.push(x as (typeof rows)[number]);
  };
  walk(body);
  const valid = rows
    .filter((r) => typeof r.recording_mbid === "string")
    .sort((a, b) => (b.score ?? 0) - (a.score ?? 0))
    .slice(0, keep);
  const top = Math.max(1, valid[0]?.score ?? 1);
  return valid.map((r) => ({
    mbid: r.recording_mbid!,
    title: r.recording_name ?? "",
    artist: r.artist_credit_name ?? "",
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
    // Enough results to include the original release, not just remasters.
    limit: "25",
  })) as { recordings?: MbRecording[] };
  const found = pickRecording(search.recordings ?? [], title, artist);
  if (found) return found;
  const id = await lookupArtistMbid(mainArtist);
  return id ? { recordingMbid: null, artistMbids: [id] } : null;
}

/**
 * The song's first release year: the earliest exact-title recording by any
 * of its artists (searched by artist ID, up to 100 results, so originals
 * aren't crowded out by live versions and remasters). Null if none.
 */
export async function lookupReleaseYear(title: string, artistMbids: string[]): Promise<number | null> {
  const wanted = normName(title);
  if (!wanted || artistMbids.length === 0) return null;
  const arids = artistMbids
    .slice(0, 3)
    .map((id) => `arid:${id}`)
    .join(" OR ");
  const body = (await mbGet("recording", {
    query: `recording:"${quote(title)}" AND (${arids})`,
    limit: "100",
  })) as { recordings?: MbRecording[] };
  const years = (body.recordings ?? [])
    .filter((r) => (r.score ?? 0) >= MIN_MATCH_SCORE && normName(r.title ?? "") === wanted)
    .map((r) => yearFrom(r["first-release-date"]))
    .filter((y): y is number => y !== null);
  return years.length ? Math.min(...years) : null;
}

/** An artist's MBID by exact name (confident matches only), or null. */
export async function lookupArtistMbid(name: string): Promise<string | null> {
  if (!name.trim()) return null;
  const artists = (await mbGet("artist", { query: `artist:"${quote(name)}"`, limit: "5" })) as {
    artists?: MbArtist[];
  };
  return pickArtist(artists.artists ?? [], name);
}

/** How many onboarding favourite artists are resolved per user. */
const MAX_FAVORITE_ARTISTS = 15;

/**
 * Resolves the user's onboarding favourite artists
 * (`users/{uid}/musicPreferences/profile.favoriteArtists`) to MBIDs, stored
 * on `userVectors/{uid}.favoriteArtists` (server-only), and caches their
 * similar artists. For You uses them so new users get similar-artist
 * picks before writing any reviews. Skips work if the list hasn't changed.
 */
export async function syncFavoriteArtists(db: Firestore, userId: string): Promise<"updated" | "unchanged"> {
  const prefs = await db.doc(`users/${userId}/musicPreferences/profile`).get();
  const names = ((prefs.get("favoriteArtists") as string[] | undefined) ?? [])
    .map((n) => String(n).trim())
    .filter(Boolean)
    .slice(0, MAX_FAVORITE_ARTISTS);
  const key = names.map((n) => n.toLowerCase()).join("|");
  const ref = db.collection(COLLECTIONS.userVectors).doc(userId);
  if ((await ref.get()).get("favoriteArtistsKey") === key) return "unchanged";
  const resolved: { mbid: string; name: string }[] = [];
  for (const name of names) {
    try {
      const mbid = await lookupArtistMbid(name);
      if (mbid) resolved.push({ mbid, name });
    } catch (e) {
      logger.warn("Favourite artist lookup failed", { userId, name, error: String(e) });
    }
  }
  await ensureSimilarArtists(
    db,
    resolved.map((r) => r.mbid),
  );
  await ref.set({ favoriteArtists: resolved, favoriteArtistsKey: key }, { merge: true });
  return "updated";
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

const LB_METADATA = "https://api.listenbrainz.org/1/metadata";
/** IDs per ListenBrainz metadata call. */
const LB_BATCH = 25;

async function lbGet(url: string): Promise<unknown> {
  for (let attempt = 1; ; attempt++) {
    const res = await fetch(url, { headers: { "User-Agent": USER_AGENT }, signal: AbortSignal.timeout(20_000) });
    if (res.ok) return res.json();
    if (res.status !== 429 && res.status !== 503) throw new Error(`ListenBrainz metadata ${res.status}`);
    if (attempt >= MB_ATTEMPTS) throw new Error(`ListenBrainz metadata ${res.status}`);
    await new Promise((r) => setTimeout(r, retryDelayMs(attempt, res.headers.get("retry-after"))));
  }
}

/** Filled-in tags for many songs at once: recording MBID → tags. */
export async function fetchRecordingTags(recordingMbids: string[]): Promise<Map<string, string[]>> {
  const out = new Map<string, string[]>();
  for (let i = 0; i < recordingMbids.length; i += LB_BATCH) {
    const ids = recordingMbids.slice(i, i + LB_BATCH);
    const body = (await lbGet(`${LB_METADATA}/recording/?recording_mbids=${ids.join(",")}&inc=tag`)) as Record<
      string,
      { tag?: Parameters<typeof pickMbTags>[0] }
    >;
    for (const id of ids) out.set(id, pickMbTags(body?.[id]?.tag));
  }
  return out;
}

/** Filled-in tags from artists alone (songs MusicBrainz doesn't have): artist MBID → tags. */
export async function fetchArtistTags(artistMbids: string[]): Promise<Map<string, string[]>> {
  const out = new Map<string, string[]>();
  for (let i = 0; i < artistMbids.length; i += LB_BATCH) {
    const ids = artistMbids.slice(i, i + LB_BATCH);
    const body = (await lbGet(`${LB_METADATA}/artist/?artist_mbids=${ids.join(",")}&inc=tag`)) as {
      artist_mbid?: string;
      tag?: { artist?: LbTag[] };
    }[];
    for (const a of Array.isArray(body) ? body : []) {
      if (a.artist_mbid) out.set(a.artist_mbid, pickMbTags({ artist: a.tag?.artist }));
    }
  }
  return out;
}

/** Filled-in tags for one review's IDs (empty if none are known). */
export async function mbTagsFor(ids: MbIds | null): Promise<string[]> {
  if (!ids) return [];
  if (ids.recordingMbid) {
    const tags = (await fetchRecordingTags([ids.recordingMbid])).get(ids.recordingMbid) ?? [];
    if (tags.length) return tags;
  }
  if (ids.artistMbids.length === 0) return [];
  const byArtist = await fetchArtistTags(ids.artistMbids.slice(0, 3));
  return [...new Set(ids.artistMbids.flatMap((id) => byArtist.get(id) ?? []))].slice(0, MB_TAGS_KEEP);
}

/** Mirrors the review's IDs and tags onto its analysis record, if it has one. */
async function mirrorToVector(
  db: Firestore,
  reviewPath: string,
  fields: Partial<{
    artistMbids: string[];
    recordingMbid: string | null;
    mbTags: string[];
    releaseYear: number | null;
    metaTags: string[];
  }>,
) {
  const ref = db.collection(COLLECTIONS.reviewVectors).doc(reviewDocId(reviewPath));
  if ((await ref.get()).exists) await ref.set(fields, { merge: true });
}

export async function fetchSimilarRecordings(recordingMbid: string): Promise<SimilarRecording[]> {
  const url = `${SIMILAR_RECORDINGS_URL}?${new URLSearchParams({
    recording_mbids: recordingMbid,
    algorithm: SIMILAR_RECORDINGS_ALGORITHM,
  })}`;
  const res = await fetch(url, { headers: { "User-Agent": USER_AGENT }, signal: AbortSignal.timeout(15_000) });
  if (!res.ok) throw new Error(`ListenBrainz similar recordings ${res.status}`);
  return parseSimilarRecordings(await res.json());
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
  if (ids?.recordingMbid) {
    try {
      const year = await lookupReleaseYear(String(data.title ?? ""), ids.artistMbids);
      if (year !== null) ids.releaseYear = Math.min(year, ids.releaseYear ?? year);
    } catch (e) {
      logger.warn("Release year lookup failed", { reviewPath, error: String(e) });
    }
  }
  let mbTags: string[] = [];
  try {
    mbTags = await mbTagsFor(ids);
  } catch (e) {
    // Tags are a bonus; the backfill fills them in later.
    logger.warn("ListenBrainz tags failed", { reviewPath, error: String(e) });
  }
  if (!opts.dryRun) {
    const releaseYear = ids?.releaseYear ?? null;
    const fields = {
      artistMbids: ids?.artistMbids ?? [],
      recordingMbid: ids?.recordingMbid ?? null,
      mbTags,
      releaseYear,
      metaTags: metaTagsFor(releaseYear),
    };
    await ref.update({ ...fields, mbKey: key });
    await mirrorToVector(db, reviewPath, fields);
  }
  return "updated";
}

/**
 * Fills in `mbTags` for reviews that have MusicBrainz IDs but no tags yet
 * (or all of them with [force]), in batches. Returns how many were written.
 */
export async function backfillMbTags(db: Firestore, opts: { dryRun?: boolean; force?: boolean } = {}): Promise<number> {
  const docs = (await db.collectionGroup("reviews").select("recordingMbid", "artistMbids", "mbTags", "isRepost").get()).docs.filter(
    (d) => d.ref.path.startsWith("users/") && !d.get("isRepost") && (opts.force || d.get("mbTags") === undefined),
  );
  const recIds = [...new Set(docs.map((d) => d.get("recordingMbid") as string | null).filter((x): x is string => !!x))];
  const byRecording = await fetchRecordingTags(recIds);
  const needArtist = docs.filter((d) => !(byRecording.get(d.get("recordingMbid"))?.length));
  const artistIds = [...new Set(needArtist.flatMap((d) => ((d.get("artistMbids") as string[]) ?? []).slice(0, 3)))];
  const byArtist = await fetchArtistTags(artistIds);
  let written = 0;
  for (const d of docs) {
    const fromSong = byRecording.get(d.get("recordingMbid")) ?? [];
    const artists = ((d.get("artistMbids") as string[]) ?? []).slice(0, 3);
    const mbTags = fromSong.length
      ? fromSong
      : [...new Set(artists.flatMap((id) => byArtist.get(id) ?? []))].slice(0, MB_TAGS_KEEP);
    if (opts.dryRun) {
      if (written < 8) console.log(`  ${d.ref.path.split("/").pop()}: ${mbTags.join(", ") || "(none)"}`);
    } else {
      await d.ref.update({ mbTags });
      await mirrorToVector(db, d.ref.path, {
        artistMbids: (d.get("artistMbids") as string[]) ?? [],
        recordingMbid: (d.get("recordingMbid") as string | null) ?? null,
        mbTags,
      });
    }
    written++;
  }
  return written;
}

/**
 * Fills in `releaseYear` + `metaTags` via [lookupReleaseYear] (one search
 * per song, ~1 a second), so a remaster's date doesn't stand in for the
 * original's. Only reviews without a year, or all
 * of them with [force]. Reviews matched to no song get an empty year.
 */
export async function backfillYears(
  db: Firestore,
  opts: { dryRun?: boolean; force?: boolean; sample?: number } = {},
): Promise<Record<string, number>> {
  const docs = (
    await db
      .collectionGroup("reviews")
      .select("title", "artist", "recordingMbid", "artistMbids", "releaseYear", "isRepost")
      .get()
  ).docs.filter(
    (d) =>
      d.ref.path.startsWith("users/") &&
      !d.get("isRepost") &&
      (opts.force || d.get("releaseYear") === undefined),
  );
  const counts: Record<string, number> = {};
  const yearOf = new Map<string, number | null>();
  let shown = 0;
  for (const d of docs) {
    let year: number | null = null;
    if (d.get("recordingMbid")) {
      const key = trackKey(String(d.get("artist") ?? ""), String(d.get("title") ?? ""));
      if (!yearOf.has(key)) {
        try {
          yearOf.set(
            key,
            await lookupReleaseYear(String(d.get("title") ?? ""), (d.get("artistMbids") as string[] | undefined) ?? []),
          );
        } catch (e) {
          counts.failed = (counts.failed ?? 0) + 1;
          continue; // retry next run
        }
      }
      year = yearOf.get(key) ?? null;
    }
    const bucket = year === null ? "no year" : `${Math.floor(year / 10) * 10}s`;
    counts[bucket] = (counts[bucket] ?? 0) + 1;
    if (opts.dryRun) {
      if (shown++ < (opts.sample ?? 10)) console.log(`  ${year ?? "—"}  ${d.get("title")} – ${d.get("artist")}`);
      continue;
    }
    const fields = { releaseYear: year, metaTags: metaTagsFor(year) };
    await d.ref.update(fields);
    await mirrorToVector(db, d.ref.path, fields);
  }
  return counts;
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

/** Fetches and caches similar songs for any of [recordingMbids] not cached recently. */
export async function ensureSimilarRecordings(db: Firestore, recordingMbids: string[]): Promise<number> {
  let fetched = 0;
  for (const mbid of recordingMbids) {
    const ref = db.collection(SIMILAR_RECORDINGS_COLLECTION).doc(mbid);
    const cached = await ref.get();
    const at = (cached.get("fetchedAt") as Timestamp | undefined)?.toMillis() ?? 0;
    if (cached.exists && Date.now() - at < SIMILAR_ARTISTS_MAX_AGE_MS) continue;
    try {
      await ref.set({ similar: await fetchSimilarRecordings(mbid), fetchedAt: FieldValue.serverTimestamp() });
      fetched++;
    } catch (e) {
      logger.warn("Similar recordings fetch failed", { mbid, error: String(e) });
    }
  }
  return fetched;
}

/** Cached similar songs: recording MBID → (similar recording MBID → 0–1). */
export async function similarRecordingsFor(
  db: Firestore,
  recordingMbids: string[],
): Promise<Map<string, Map<string, number>>> {
  const out = new Map<string, Map<string, number>>();
  for (let i = 0; i < recordingMbids.length; i += 300) {
    const refs = recordingMbids.slice(i, i + 300).map((id) => db.collection(SIMILAR_RECORDINGS_COLLECTION).doc(id));
    if (refs.length === 0) continue;
    for (const s of await db.getAll(...refs)) {
      if (!s.exists) continue;
      const list = (s.get("similar") as SimilarRecording[] | undefined) ?? [];
      out.set(s.id, new Map(list.map((r) => [r.mbid, r.score])));
    }
  }
  return out;
}

/** Cached similar artists for each of [artistMbids] (missing ones left out). */
export async function similarArtistsFor(db: Firestore, artistMbids: string[]): Promise<Map<string, SimilarArtist[]>> {
  const out = new Map<string, SimilarArtist[]>();
  if (artistMbids.length === 0) return out;
  const snaps = await db.getAll(...artistMbids.map((id) => db.collection(SIMILAR_ARTISTS_COLLECTION).doc(id)));
  snaps.forEach((s) => s.exists && out.set(s.id, (s.get("similar") as SimilarArtist[]) ?? []));
  return out;
}
