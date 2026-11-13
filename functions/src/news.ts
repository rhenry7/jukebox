/**
 * "Best New Music": album reviews from Pitchfork, Stereogum, NME, Billboard,
 * The Guardian and The Quietus, shown on the Search page before the user
 * types. Each carries broad genres (the sites' own tags + the artist's
 * MusicBrainz tags) and the artist's MBID, for the page's genre and
 * "For you" filters.
 *
 * The app can't read these feeds itself (browsers block cross-site requests
 * on the web), so `refreshMusicNews` fetches them every few hours into
 * `musicNews/{id}` (public read, server write). Pitchfork's and NME's images
 * don't allow cross-site loading either, so the app shows every item's image
 * through `newsImage?id=…`, which serves only images of stored items (never
 * an arbitrary URL).
 */
import { createHash } from "node:crypto";
import { Firestore, Timestamp } from "firebase-admin/firestore";
import { fetchArtistTags, lookupArtistMbid, normName } from "./musicbrainz";

export const NEWS_COLLECTION = "musicNews";

/** How many recent items each source keeps. */
export const NEWS_PER_SOURCE = 12;

/** Older reviews are dropped (Billboard's review feeds go back years). */
export const NEWS_MAX_AGE_DAYS = 365;

export type NewsSourceId = "pitchfork" | "stereogum" | "nme" | "billboard" | "guardian" | "quietus";

export interface NewsSource {
  id: NewsSourceId;
  name: string;
  /** The kind of pick, shown on the card ("Best New Album"). */
  label: string;
  /** RSS feeds, merged (a site can file reviews under several). */
  feeds: string[];
  /** Keeps only album reviews, for feeds that carry other posts too. */
  keep?: (item: FeedItem) => boolean;
}

/**
 * Filed as a music review. Billboard tags album reviews "Album Reviews",
 * "album review" or "Reviews"; its product reviews (headphones, turntables)
 * are tagged plain "Review", so the singular alone doesn't count.
 */
export const isReview = (item: FeedItem) =>
  item.categories.some((c) => /^album reviews?$|^reviews$/i.test(c.trim())) || /critic.s take/i.test(item.title);

export const NEWS_SOURCES: NewsSource[] = [
  {
    id: "pitchfork",
    name: "Pitchfork",
    label: "Best New Album",
    feeds: ["https://pitchfork.com/feed/reviews/best/albums/rss"],
  },
  {
    id: "stereogum",
    name: "Stereogum",
    label: "Album of the Week",
    feeds: ["https://www.stereogum.com/category/album-of-the-week/feed/"],
  },
  {
    id: "nme",
    name: "NME",
    label: "Album Review",
    feeds: ["https://www.nme.com/reviews/album/feed"],
    keep: isReview,
  },
  {
    id: "billboard",
    name: "Billboard",
    label: "Album Review",
    feeds: [
      "https://www.billboard.com/t/album-reviews/feed/",
      "https://www.billboard.com/t/album-review/feed/",
      "https://www.billboard.com/c/music/reviews/feed/",
      "https://www.billboard.com/t/reviews/feed/",
      // The main music feed, filtered: the odd review lands only here.
      "https://www.billboard.com/feed/",
    ],
    keep: isReview,
  },
  {
    id: "guardian",
    name: "The Guardian",
    label: "Album Review",
    feeds: ["https://www.theguardian.com/music+tone/albumreview/rss"],
  },
  {
    id: "quietus",
    name: "The Quietus",
    label: "Album Review",
    // The main feed: news, features and reviews; reviews are tagged so.
    feeds: ["https://thequietus.com/feed"],
    keep: (item) => item.categories.some((c) => /^reviews?$/i.test(c.trim())),
  },
];

export interface FeedItem {
  title: string;
  link: string;
  summary: string;
  author: string;
  categories: string[];
  imageUrl: string | null;
  publishedAt: Date | null;
}

export interface NewsItem {
  id: string;
  source: NewsSourceId;
  sourceName: string;
  label: string;
  /** The site's headline. */
  title: string;
  /** Split out of the headline where the site's format allows ("" if not). */
  album: string;
  artist: string;
  /** The critic's one-line take (NME's "review: brighter, poppier…"). */
  verdict: string;
  summary: string;
  author: string;
  url: string;
  imageUrl: string | null;
  publishedAt: Date;
  /** Genre-like tags: the site's own (when it has them) + MusicBrainz's. */
  tags: string[];
  /** Broad genres ([GENRES]) from [tags], at most two. */
  genres: string[];
  /** The artist's MusicBrainz ID, when found (empty if not). */
  artistMbids: string[];
}

export interface TitleParts {
  album: string;
  artist: string;
  verdict: string;
  /** Overrides the source's label ("Album of the Week" on The Guardian). */
  label?: string;
}

const NONE: TitleParts = { album: "", artist: "", verdict: "" };

const capitalize = (s: string) => (s ? s[0].toUpperCase() + s.slice(1) : s);

const slugify = (s: string) =>
  s
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f’'".,!?()]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

/** Generic tags that aren't an artist's name. */
const NOT_ARTISTS = /^(album of the week|reviews?|album reviews?|music|news)$/i;

/**
 * Album, artist and verdict from a headline, per site:
 *  - NME: "U2 – ‘Carnaval de Luz’ review: brighter, poppier…"
 *  - Billboard: "Cardi B’s ‘Drama’ Recaptures Her Crown (Critic’s Take)"
 *  - Stereogum: "Krill Secret Language", the artist being one of the tags
 *  - Pitchfork: the album alone; the artist is the rest of the link's slug
 *    (`/reviews/albums/baby-osamaa-on-tha-run/`), so only its letters, not
 *    its capitals, are certain.
 * Anything that doesn't fit gives "" and the card shows the headline.
 */
export function titleParts(source: NewsSourceId, title: string, link: string, categories: string[]): TitleParts {
  switch (source) {
    case "nme": {
      const m = title.match(/^(.+?)\s+[–—-]\s+[‘'"“](.+?)[’'"”]\s+(?:(?:EP|album|mixtape)\s+)?review\b:?\s*(.*)$/i);
      return m ? { artist: m[1].trim(), album: m[2].trim(), verdict: capitalize(m[3].trim()) } : NONE;
    }
    case "billboard": {
      // The closing quote is the one before ":", a space or the end, so
      // "‘I’m So Happy’" keeps its apostrophe.
      const m = title.match(/^(.+?)[’']s\s+[‘'"“](.+?)[’'"”](?=:|\s|$):?\s*(.*)$/);
      return m ? { artist: m[1].trim(), album: m[2].trim(), verdict: capitalize(m[3].trim()) } : NONE;
    }
    case "stereogum": {
      const lower = title.toLowerCase();
      const artist = categories
        .filter((c) => !NOT_ARTISTS.test(c.trim()) && lower.startsWith(c.trim().toLowerCase() + " "))
        .sort((a, b) => b.length - a.length)[0]
        ?.trim();
      return artist ? { artist, album: title.slice(artist.length).trim(), verdict: "" } : NONE;
    }
    case "pitchfork": {
      const slug = link.match(/\/reviews\/albums\/([^/?#]+)/)?.[1] ?? "";
      const albumSlug = slugify(title);
      const artistSlug = albumSlug && slug.endsWith("-" + albumSlug) ? slug.slice(0, -albumSlug.length - 1) : "";
      const artist = artistSlug
        .split("-")
        .filter(Boolean)
        .map(capitalize)
        .join(" ");
      return { album: title, artist, verdict: "" };
    }
    case "guardian": {
      // "Snoh Aalegra: Legendary Love review – raw R&B talent …" or
      // "Blackhaine: Saints in the Wethouse review | Alexis Petridis's album of
      // the week". Classical reviews ("Giulio Cesare in Egitto album review")
      // have no "Artist:" and are left out.
      const m = title.match(/^(.+?):\s+(.+?)\s+review\b(.*)$/i);
      if (!m) return NONE;
      const rest = m[3];
      const pick = rest.match(/album of the (week|month)/i);
      return {
        artist: m[1].trim(),
        album: m[2].trim(),
        verdict: capitalize(rest.replace(/\|.*$/, "").replace(/^\s*[–—-]\s*/, "").trim()),
        ...(pick ? { label: `Album of the ${capitalize(pick[1].toLowerCase())}` } : {}),
      };
    }
    case "quietus": {
      const m = title.match(/^(.+?)\s+[–—]\s+(.+)$/);
      return m ? { artist: m[1].trim(), album: m[2].trim(), verdict: "" } : NONE;
    }
  }
}

/**
 * The broad genres of the page's filter row, each with the tags that mean
 * it. Matched on whole words, in this order; a review keeps its first two.
 */
export const GENRES: [string, RegExp][] = [
  ["Hip-hop", /\b(hip[- ]?hop|hiphop|rap|grime|trap|drill|boom bap)\b/],
  ["R&B", /(^|\W)(r&b|rnb|soul|neo[- ]soul|funk)(\W|$)/],
  ["Electronic", /\b(electronic|electronica|house|techno|edm|dubstep|uk garage|drum and bass|dnb|jungle|idm|trance|club)\b/],
  ["Metal", /\b(metal|metalcore|doom|sludge|grindcore|deathcore)\b/],
  ["Rock", /\b(rock|punk|post-punk|shoegaze|grunge|emo|indie|hardcore)\b/],
  ["Pop", /\b(pop|k-pop|synthpop|electropop|hyperpop|dance-pop)\b/],
  ["Folk & Country", /\b(folk|country|americana|singer[- ]songwriter|bluegrass)\b/],
  ["Jazz", /\bjazz\b/],
  ["Experimental", /\b(experimental|avant[- ]garde|noise|drone|ambient)\b/],
  ["Classical", /\b(classical|opera|orchestral|baroque)\b/],
  ["Global", /\b(afrobeats?|afropop|amapiano|latin|reggaeton|reggae|dancehall|global)\b/],
];

/** Site tags too broad to mean a genre (The Guardian files rock and pop alike under one). */
const TOO_BROAD = /^(pop and rock|music|culture|reviews?|album reviews?|news)$/i;

/** Tags (most relevant first) → up to two broad genres. */
export function genresFor(tags: string[]): string[] {
  const out: string[] = [];
  for (const raw of tags) {
    const t = raw.toLowerCase().trim();
    if (TOO_BROAD.test(t)) continue;
    for (const [genre, re] of GENRES) {
      if (re.test(t) && !out.includes(genre)) out.push(genre);
    }
    if (out.length >= 2) break;
  }
  return out.slice(0, 2);
}

/** The site's own tags that name a genre (not artists, sections or "Reviews"). */
export function siteGenreTags(categories: string[]): string[] {
  return categories
    .map((c) => c.trim().toLowerCase().replace(/^genre\s+/, ""))
    .filter((c) => !TOO_BROAD.test(c) && genresFor([c]).length > 0);
}

const ENTITIES: Record<string, string> = {
  amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ", hellip: "…",
  rsquo: "’", lsquo: "‘", rdquo: "”", ldquo: "“", ndash: "–", mdash: "—",
};

export function decodeEntities(s: string): string {
  return s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, e: string) => {
    if (e[0] === "#") {
      const code = e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
      return Number.isFinite(code) ? String.fromCodePoint(code) : m;
    }
    return ENTITIES[e.toLowerCase()] ?? m;
  });
}

/** Text of an RSS field: CDATA unwrapped, entities decoded, tags removed. */
export function plainText(raw: string): string {
  const unwrapped = raw.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1");
  // Decode first: some feeds escape their markup (`&lt;em&gt;`).
  // Block tags separate words; inline ones (<em>, <b>) sit inside them.
  const text = decodeEntities(unwrapped)
    .replace(/<\/?(p|br|div|li|h\d)\b[^>]*>/gi, " ")
    .replace(/<[^>]*>/g, "");
  return decodeEntities(text).replace(/\s+/g, " ").trim();
}

function field(xml: string, tag: string): string {
  const m = xml.match(new RegExp(`<${tag}(?:\\s[^>]*)?>([\\s\\S]*?)</${tag}>`, "i"));
  return m ? m[1] : "";
}

function attr(xml: string, tag: string, name: string): string | null {
  const m = xml.match(new RegExp(`<${tag}\\b[^>]*\\b${name}="([^"]+)"`, "i"));
  return m ? decodeEntities(m[1]) : null;
}

/** Every image URL anywhere in an item (tags, srcsets, escaped HTML). */
function imageUrlsIn(item: string): string[] {
  const text = decodeEntities(decodeEntities(item));
  return [...new Set(text.match(/https:\/\/[^\s"'<>]+?\.(?:jpe?g|png|webp)(?:\?[^\s"'<>]*)?(?=[\s"'<>]|$)/gi) ?? [])];
}

const fileStem = (url: string) => url.replace(/[?#].*$/, "").replace(/(-\d+x\d+)?\.(jpe?g|png|webp)$/i, "");

/**
 * The `media:content` closest to 640 px wide when a feed lists several sizes
 * (The Guardian: 140, 460, 700), else null.
 */
function sizedMediaContent(item: string): string | null {
  const sizes = [...item.matchAll(/<media:content\b[^>]*>/gi)]
    .map((m) => ({ url: m[0].match(/\burl="([^"]+)"/)?.[1], width: Number(m[0].match(/\bwidth="(\d+)"/)?.[1]) }))
    .filter((x): x is { url: string; width: number } => !!x.url && x.width > 0);
  if (sizes.length < 2) return null;
  sizes.sort((a, b) => Math.abs(a.width - 640) - Math.abs(b.width - 640));
  return decodeEntities(sizes[0].url);
}

/**
 * The item's image: its album artwork when the post includes it (NME puts a
 * press photo first and the cover further down), else the feed's main image;
 * and, when the post lists resized copies (WordPress srcsets), one 400–800 px
 * wide, so the app doesn't download a 1 MB photo for a thumbnail.
 */
export function imageOf(item: string): string | null {
  const urls = imageUrlsIn(item);
  const main =
    sizedMediaContent(item) ??
    attr(item, "media:thumbnail", "url") ??
    attr(item, "media:content", "url") ??
    attr(item, "enclosure", "url") ??
    (decodeEntities(field(item, "content:encoded") + field(item, "description")).match(/<img[^>]+src="([^"]+)"/i)?.[1] ??
      null);
  const artwork = urls.find((u) => /(artwork|album[-_ ]?art|album[-_ ]?cover|[-_/]cover[-_.])/i.test(u.split("/").pop() ?? ""));
  const chosen = artwork ?? main;
  if (!chosen || !/^https:\/\//.test(chosen)) return null;
  const sized = urls.find((u) => {
    const m = u.match(/-(\d+)x\d+\.(jpe?g|png|webp)/i);
    return m !== null && fileStem(u) === fileStem(chosen) && +m[1] >= 400 && +m[1] <= 800;
  });
  return sized ?? chosen;
}

/** The items of an RSS feed. No XML library: feeds are flat and regular. */
export function parseFeed(xml: string): FeedItem[] {
  const items = xml.match(/<item\b[\s\S]*?<\/item>/gi) ?? [];
  return items.map((item) => {
    const date = new Date(plainText(field(item, "pubDate")));
    return {
      title: plainText(field(item, "title")),
      link: plainText(field(item, "link")),
      summary: plainText(field(item, "description")),
      author: plainText(field(item, "dc:creator")),
      categories: [...item.matchAll(/<category\b[^>]*>([\s\S]*?)<\/category>/gi)].map((m) => plainText(m[1])),
      imageUrl: imageOf(item),
      publishedAt: Number.isNaN(date.getTime()) ? null : date,
    };
  });
}

/** Stable id for a review, from its link. */
export function newsId(link: string): string {
  return createHash("sha1").update(link.replace(/[?#].*$/, "").replace(/\/+$/, "")).digest("hex").slice(0, 20);
}

/**
 * Cleans a feed item up for the card: drops the site's boilerplate
 * ("Album Of The Week:" prefixes, WordPress "The post … appeared first on"
 * summaries) and keeps summaries to a couple of lines.
 */
export function toNewsItem(source: NewsSource, item: FeedItem): NewsItem | null {
  if (!item.title || !/^https:\/\//.test(item.link) || !item.publishedAt) return null;
  if (source.keep && !source.keep(item)) return null;
  if (Date.now() - item.publishedAt.getTime() > NEWS_MAX_AGE_DAYS * 86_400_000) return null;
  const title = item.title.replace(/^album of the week:\s*/i, "");
  // Album reviews only: a headline we can't split into album and artist is
  // a concert write-up, a ranking or a feature, which clutters the list.
  const parts = titleParts(source.id, title, item.link, item.categories);
  if (!parts.album || !parts.artist) return null;
  // WordPress appends "The post … appeared first on NME." to excerpts.
  let summary = item.summary.replace(/\s*The post [\s\S]*? appeared first on [^.]+\.?\s*$/i, "");
  // The Guardian ends excerpts with "Continue reading…".
  summary = summary.replace(/\s*Continue reading(\.\.\.|…)?\s*$/i, "");
  // The Quietus starts every excerpt with "Artist Album".
  const lead = `${parts.artist} ${parts.album}`;
  if (summary.toLowerCase().startsWith(lead.toLowerCase())) summary = summary.slice(lead.length).trim();
  if (summary.length > 220) summary = summary.slice(0, 217).replace(/\s+\S*$/, "") + "…";
  return {
    id: newsId(item.link),
    source: source.id,
    sourceName: source.name,
    label: parts.label ?? source.label,
    title,
    album: parts.album,
    artist: parts.artist,
    verdict: parts.verdict,
    summary,
    author: item.author,
    url: item.link,
    imageUrl: item.imageUrl,
    publishedAt: item.publishedAt,
    tags: siteGenreTags(item.categories),
    genres: genresFor(siteGenreTags(item.categories)),
    artistMbids: [],
  };
}

/** The newest [NEWS_PER_SOURCE] reviews from one source's feeds' XML. */
export function newsFromFeed(source: NewsSource, xml: string | string[]): NewsItem[] {
  const seen = new Set<string>();
  return (Array.isArray(xml) ? xml : [xml])
    .flatMap(parseFeed)
    .map((item) => toNewsItem(source, item))
    .filter((n): n is NewsItem => n !== null && !seen.has(n.id) && (seen.add(n.id), true))
    .sort((a, b) => b.publishedAt.getTime() - a.publishedAt.getTime())
    .slice(0, NEWS_PER_SOURCE);
}

const USER_AGENT = "REVERB/1.0 (music reviews app; +https://juxeboxd.web.app)";

async function fetchText(url: string): Promise<string> {
  const res = await fetch(url, {
    headers: { "User-Agent": USER_AGENT, Accept: "application/rss+xml, application/xml, text/xml" },
    redirect: "follow",
    signal: AbortSignal.timeout(20_000),
  });
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  return res.text();
}

export interface NewsSyncResult {
  written: number;
  removed: number;
  failed: string[];
}

/** Image formats the app can draw everywhere (AVIF can't on phones). */
const DRAWABLE_IMAGE = /\.(jpe?g|png|webp|gif)(\?|$)|i\.guim\.co\.uk|media\.pitchfork\.com/i;

export interface ItunesAlbum {
  artistName?: string;
  collectionName?: string;
  artworkUrl100?: string;
}

/**
 * The cover from Apple's catalogue for [album] by [artist]: names must
 * match (ignoring case, punctuation and "- EP" / "(Deluxe)" endings); the
 * 100 px artwork link is asked for at 600 px. Null if nothing matches.
 */
export function pickItunesCover(artist: string, album: string, results: ItunesAlbum[]): string | null {
  const want = normName(album.replace(/\s*[([].*$/, ""));
  const who = normName(mainArtist(artist));
  for (const r of results) {
    const name = normName((r.collectionName ?? "").replace(/\s*[([].*$|\s+-\s+(ep|single)$/i, ""));
    const by = normName(r.artistName ?? "");
    if (!r.artworkUrl100 || !want || !who) continue;
    if (name === want && (by === who || by.includes(who))) {
      return r.artworkUrl100.replace(/\/\d+x\d+bb\./, "/600x600bb.");
    }
  }
  return null;
}

async function itunesCover(artist: string, album: string): Promise<string | null> {
  const url = `https://itunes.apple.com/search?${new URLSearchParams({
    term: `${mainArtist(artist)} ${album}`,
    entity: "album",
    limit: "10",
  })}`;
  const res = await fetch(url, { headers: { "User-Agent": USER_AGENT }, signal: AbortSignal.timeout(10_000) });
  if (!res.ok) return null;
  const body = (await res.json()) as { results?: ItunesAlbum[] };
  return pickItunesCover(artist, album, body.results ?? []);
}

/**
 * Items whose image the app can't draw (The Quietus serves only AVIF) or
 * that have none get the album's cover from Apple's catalogue instead, or
 * no image if Apple doesn't have it.
 */
async function fillCovers(items: NewsItem[]): Promise<void> {
  for (const item of items) {
    if (item.imageUrl && DRAWABLE_IMAGE.test(item.imageUrl)) continue;
    try {
      item.imageUrl = await itunesCover(item.artist, item.album);
    } catch {
      item.imageUrl = null;
    }
  }
}

/** Server-only cache of each news artist's MBID and MusicBrainz tags. */
export const NEWS_ARTISTS_COLLECTION = "newsArtists";

/** How long a cached artist lasts (a miss is retried sooner). */
const ARTIST_TTL_MS = 30 * 86_400_000;
const ARTIST_MISS_TTL_MS = 7 * 86_400_000;

/** New artists looked up per run (MusicBrainz allows about one call a second). */
const ARTIST_LOOKUPS_PER_RUN = 60;

/** The artist to look up: the first named ("Erykah Badu & The Alchemist" → "Erykah Badu"). */
export function mainArtist(artist: string): string {
  return artist.split(/\s*(?:,|&|\band\b|\bfeat\.?|\bx\b)\s*/i)[0].trim();
}

const artistKey = (name: string) => createHash("sha1").update(normName(name)).digest("hex").slice(0, 20);

interface CachedArtist {
  mbid: string | null;
  tags: string[];
}

/**
 * Fills in each item's artist MBID, MusicBrainz tags and so its genres,
 * from the cache, looking up artists it doesn't have (up to
 * [ARTIST_LOOKUPS_PER_RUN] a run; the rest next run). Lookup failures just
 * leave an item with its site tags.
 */
async function enrichArtists(db: Firestore, items: NewsItem[], dryRun: boolean): Promise<void> {
  const col = db.collection(NEWS_ARTISTS_COLLECTION);
  const names = [...new Set(items.map((i) => mainArtist(i.artist)).filter(Boolean))];
  const snaps = names.length ? await db.getAll(...names.map((n) => col.doc(artistKey(n)))) : [];
  const cache = new Map<string, CachedArtist>();
  const now = Date.now();
  const stale: string[] = [];
  names.forEach((name, i) => {
    const d = snaps[i];
    const fetched = (d.get("fetchedAt") as Timestamp | undefined)?.toMillis() ?? 0;
    const mbid = (d.get("mbid") as string | null | undefined) ?? null;
    if (d.exists) cache.set(name, { mbid, tags: (d.get("tags") as string[] | undefined) ?? [] });
    if (!d.exists || now - fetched > (mbid ? ARTIST_TTL_MS : ARTIST_MISS_TTL_MS)) stale.push(name);
  });

  const found = new Map<string, string | null>();
  for (const name of stale.slice(0, ARTIST_LOOKUPS_PER_RUN)) {
    try {
      found.set(name, await lookupArtistMbid(name));
    } catch {
      // MusicBrainz busy: try again next run.
    }
  }
  const ids = [...found.values()].filter((x): x is string => !!x);
  let tagsById = new Map<string, string[]>();
  try {
    tagsById = ids.length ? await fetchArtistTags(ids) : tagsById;
  } catch {
    // ListenBrainz down: keep the MBIDs, tags next time.
  }
  const writer = dryRun ? null : db.bulkWriter();
  for (const [name, mbid] of found) {
    const entry = { mbid, tags: mbid ? (tagsById.get(mbid) ?? []) : [] };
    cache.set(name, entry);
    writer?.set(col.doc(artistKey(name)), { name, ...entry, fetchedAt: Timestamp.now() });
  }
  await writer?.close();

  for (const item of items) {
    const a = cache.get(mainArtist(item.artist));
    if (!a) continue;
    if (a.mbid) item.artistMbids = [a.mbid];
    item.tags = [...new Set([...item.tags, ...a.tags.map((t) => t.toLowerCase())])].slice(0, 8);
    item.genres = genresFor(item.tags);
  }
}

/**
 * Fetches every source and stores its newest reviews. A source whose feed
 * fails keeps what it had, so one site being down never empties the list.
 */
export async function syncMusicNews(db: Firestore, { dryRun = false } = {}): Promise<NewsSyncResult> {
  const result: NewsSyncResult = { written: 0, removed: 0, failed: [] };
  const col = db.collection(NEWS_COLLECTION);
  const fetched: { source: NewsSource; items: NewsItem[] }[] = [];
  for (const source of NEWS_SOURCES) {
    // A source counts as fetched if any of its feeds answered.
    const settled = await Promise.allSettled(source.feeds.map(fetchText));
    const xml = settled.flatMap((r) => (r.status === "fulfilled" ? [r.value] : []));
    for (const r of settled) if (r.status === "rejected") result.failed.push(`${source.name}: ${String(r.reason)}`);
    if (xml.length === 0) continue;
    const items = newsFromFeed(source, xml);
    if (items.length === 0) {
      result.failed.push(`${source.name}: no reviews in the feed`);
      continue;
    }
    fetched.push({ source, items });
  }
  await enrichArtists(
    db,
    fetched.flatMap((f) => f.items),
    dryRun,
  );
  await fillCovers(fetched.flatMap((f) => f.items));
  for (const { source, items } of fetched) {
    const keep = new Set(items.map((n) => n.id));
    const stale = (await col.where("source", "==", source.id).get()).docs.filter((d) => !keep.has(d.id));
    result.written += items.length;
    result.removed += stale.length;
    if (dryRun) continue;
    const batch = db.batch();
    for (const n of items) {
      const { id, publishedAt, ...rest } = n;
      batch.set(col.doc(id), { ...rest, publishedAt: Timestamp.fromDate(publishedAt), fetchedAt: Timestamp.now() });
    }
    for (const d of stale) batch.delete(d.ref);
    await batch.commit();
  }
  return result;
}

/**
 * A smaller copy of a site's image where the site can resize (all four can),
 * so a card thumbnail doesn't download a 1600 px photo.
 */
export function smallImageUrl(url: string, width = 640): string {
  if (/media\.pitchfork\.com\/photos\/[^/]+\/master\/pass\//.test(url)) {
    return url.replace("/master/pass/", `/master/w_${width},c_limit/`);
  }
  if (/\/wp-content\/uploads\//.test(url)) {
    const u = new URL(url);
    u.search = "";
    u.searchParams.set("w", String(width));
    return u.toString();
  }
  return url;
}

/** Image bytes for a stored news item, or null if it has none. */
export async function fetchNewsImage(
  db: Firestore,
  id: string,
): Promise<{ body: Buffer; contentType: string } | null> {
  if (!/^[0-9a-f]{20}$/.test(id)) return null;
  const doc = await db.collection(NEWS_COLLECTION).doc(id).get();
  const original = doc.get("imageUrl") as string | undefined;
  if (!original) return null;
  for (const url of [smallImageUrl(original), original]) {
    const res = await fetch(url, { headers: { "User-Agent": USER_AGENT }, signal: AbortSignal.timeout(15_000) });
    const contentType = res.headers.get("content-type") ?? "";
    if (res.ok && contentType.startsWith("image/")) {
      return { body: Buffer.from(await res.arrayBuffer()), contentType };
    }
    if (url === original) break;
  }
  return null;
}
