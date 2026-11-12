/**
 * "Best New Music": review headlines from Pitchfork, Stereogum, NME and
 * Billboard, shown on the Search page before the user types.
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

export const NEWS_COLLECTION = "musicNews";

/** How many recent items each source keeps. */
export const NEWS_PER_SOURCE = 12;

/** Older reviews are dropped (Billboard's review feeds go back years). */
export const NEWS_MAX_AGE_DAYS = 365;

export type NewsSourceId = "pitchfork" | "stereogum" | "nme" | "billboard";

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
}

export interface TitleParts {
  album: string;
  artist: string;
  verdict: string;
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
  }
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
 * The item's image: its album artwork when the post includes it (NME puts a
 * press photo first and the cover further down), else the feed's main image;
 * and, when the post lists resized copies (WordPress srcsets), one 400–800 px
 * wide, so the app doesn't download a 1 MB photo for a thumbnail.
 */
export function imageOf(item: string): string | null {
  const urls = imageUrlsIn(item);
  const main =
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
  if (summary.length > 220) summary = summary.slice(0, 217).replace(/\s+\S*$/, "") + "…";
  return {
    id: newsId(item.link),
    source: source.id,
    sourceName: source.name,
    label: source.label,
    title,
    ...parts,
    summary,
    author: item.author,
    url: item.link,
    imageUrl: item.imageUrl,
    publishedAt: item.publishedAt,
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

/**
 * Fetches every source and stores its newest reviews. A source whose feed
 * fails keeps what it had, so one site being down never empties the list.
 */
export async function syncMusicNews(db: Firestore, { dryRun = false } = {}): Promise<NewsSyncResult> {
  const result: NewsSyncResult = { written: 0, removed: 0, failed: [] };
  const col = db.collection(NEWS_COLLECTION);
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
