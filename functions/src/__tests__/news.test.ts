import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { imageOf, isReview, NEWS_SOURCES, titleParts, newsFromFeed, newsId, parseFeed, plainText, smallImageUrl } from "../news";

const source = (id: string) => NEWS_SOURCES.find((s) => s.id === id)!;

const pitchfork = `<rss><channel><item><title>On Tha Run</title>
<link>https://pitchfork.com/reviews/albums/baby-osamaa-on-tha-run/</link>
<pubDate>Wed, 04 Nov 2026 05:03:00 +0000</pubDate><media:content/>
<description>With delirious melodic instincts, the Bronx rapper&#8217;s new tape evokes Young Money-era swag.</description>
<category>Reviews / Albums</category><dc:creator>Alphonse Pierre</dc:creator>
<media:thumbnail url="https://media.pitchfork.com/photos/6aea/master/pass/Baby%20Osamaa.jpg" width="1600"/></item>
<item><title>Jazz dreams</title><link>https://pitchfork.com/reviews/albums/fine-jazz-dreams/</link>
<pubDate>Fri, 23 Oct 2026 04:03:00 +0000</pubDate><description>Future standards.</description>
<dc:creator>Hattie Lindert</dc:creator></item></channel></rss>`;

const stereogum = `<rss><channel><item>
<title>Album Of The Week: Krill Secret Language</title>
<link>https://stereogum.com/2517187/album-of-the-week-krill-secret-language/reviews/album-of-the-week/</link>
<dc:creator><![CDATA[Chris DeVille]]></dc:creator><pubDate>Tue, 10 Nov 2026 21:01:17 +0000</pubDate>
<category><![CDATA[Album Of The Week]]></category><category><![CDATA[Krill]]></category>
<description><![CDATA[<p>The post <a href="https://stereogum.com/x/">Album Of The Week: Krill &lt;em&gt;Secret Language&lt;/em&gt;</a> appeared first on <a href="https://stereogum.com">Stereogum</a>.</p>]]></description>
<media:content medium="image" url="https://lede-admin.stereogum.com/wp-content/uploads/sites/64/2026/11/krill.jpg?w=564"/>
</item></channel></rss>`;

const billboard = `<rss><channel>
<item><title><![CDATA[Cardi B’s ‘Drama’ Recaptures Her Crown (Critic’s Take)]]></title>
<link>https://www.billboard.com/music/cardi-b-drama-review/</link><pubDate>Mon, 09 Nov 2026 10:00:00 +0000</pubDate>
<category><![CDATA[Music]]></category><category><![CDATA[album review]]></category>
<description><![CDATA[<p>Big, loud and <b>fun</b>.</p>]]></description></item>
<item><title><![CDATA[‘SPY×FAMILY’ Tops Billboard Japan Book Hot 100]]></title>
<link>https://www.billboard.com/music/spy-family/</link><pubDate>Thu, 12 Nov 2026 18:40:34 +0000</pubDate>
<category><![CDATA[Chart Beat]]></category></item>
</channel></rss>`;

describe("music news", () => {
  it("reads RSS fields: CDATA, entities, escaped markup", () => {
    const [item] = parseFeed(stereogum);
    assert.equal(item.author, "Chris DeVille");
    assert.deepEqual(item.categories, ["Album Of The Week", "Krill"]);
    assert.equal(item.imageUrl, "https://lede-admin.stereogum.com/wp-content/uploads/sites/64/2026/11/krill.jpg?w=564");
    assert.equal(plainText("Krill &lt;em&gt;Secret Language&lt;/em&gt;"), "Krill Secret Language");
    assert.equal(parseFeed(pitchfork)[0].summary, "With delirious melodic instincts, the Bronx rapper’s new tape evokes Young Money-era swag.");
  });

  it("Pitchfork: newest first, thumbnail image, items without art kept", () => {
    const items = newsFromFeed(source("pitchfork"), pitchfork);
    assert.deepEqual(items.map((n) => n.title), ["On Tha Run", "Jazz dreams"]);
    assert.equal(items[0].label, "Best New Album");
    assert.equal(items[0].author, "Alphonse Pierre");
    assert.match(items[0].imageUrl!, /media\.pitchfork\.com/);
    assert.equal(items[1].imageUrl, null);
  });

  it("Stereogum: drops the prefix and the WordPress boilerplate summary", () => {
    const [item] = newsFromFeed(source("stereogum"), stereogum);
    assert.equal(item.title, "Krill Secret Language");
    assert.equal(item.summary, "");
    assert.equal(item.label, "Album of the Week");
  });

  it("NME: the WordPress line after a real summary is dropped", () => {
    const xml = `<item><title>U2 – ‘Carnaval de Luz’ review</title><link>https://www.nme.com/reviews/album/u2/</link>
<pubDate>Thu, 12 Nov 2026 09:00:41 +0000</pubDate><category>Album Reviews</category>
<description><![CDATA[<p>The Irish legends sound playful.</p><p>The post <a href="https://www.nme.com/x">U2 – ‘Carnaval de Luz’ review</a> appeared first on <a href="https://www.nme.com">NME</a>.</p>]]></description></item>`;
    assert.equal(newsFromFeed(source("nme"), xml)[0].summary, "The Irish legends sound playful.");
  });

  it("Billboard / NME: keeps reviews, drops other news", () => {
    const items = newsFromFeed(source("billboard"), billboard);
    assert.equal(items.length, 1);
    assert.match(items[0].title, /Cardi B/);
    assert.equal(items[0].summary, "Big, loud and fun.");
  });

  it("Billboard's product reviews aren't music reviews; old reviews drop off", () => {
    const item = { ...parseFeed(billboard)[0], title: "These Headphones Are Made for Music", categories: ["Culture", "Product Recommendations", "Review"] };
    assert.equal(isReview(item), false);
    assert.equal(isReview({ ...item, categories: ["Music", "Album Reviews"] }), true);
    assert.equal(isReview({ ...item, categories: ["Music", "Reviews"] }), true);
    const old = billboard.replace("Mon, 09 Nov 2026", "Mon, 09 Nov 2020");
    assert.equal(newsFromFeed(source("billboard"), old).length, 0);
  });

  it("merges a source's feeds without duplicates", () => {
    assert.equal(newsFromFeed(source("billboard"), [billboard, billboard]).length, 1);
  });

  it("prefers the album artwork, and a resized copy when the post lists one", () => {
    const nme = `<item><media:content url="https://www.nme.com/wp-content/uploads/2026/11/U2-Credit.jpg"/>
<content:encoded><![CDATA[<img src="https://www.nme.com/wp-content/uploads/2026/11/U2-Credit-696x442.jpg"
srcset="https://www.nme.com/wp-content/uploads/2026/11/U2-Credit-1392x884.jpg 1392w">
<img src="https://www.nme.com/wp-content/uploads/2026/11/U2-Carnaval-De-Luz-Artwork.jpg">]]></content:encoded></item>`;
    assert.equal(imageOf(nme), "https://www.nme.com/wp-content/uploads/2026/11/U2-Carnaval-De-Luz-Artwork.jpg");
    const noArt = nme.replace(/<img src="[^"]*Artwork\.jpg">/, "");
    assert.equal(imageOf(noArt), "https://www.nme.com/wp-content/uploads/2026/11/U2-Credit-696x442.jpg");
    assert.equal(imageOf("<item><title>x</title></item>"), null);
  });

  it("splits album, artist and verdict out of each site's headlines", () => {
    assert.deepEqual(
      titleParts("nme", "U2 – ‘Carnaval de Luz’ review: brighter, poppier and still a little bit bombastic", "", []),
      { artist: "U2", album: "Carnaval de Luz", verdict: "Brighter, poppier and still a little bit bombastic" },
    );
    assert.deepEqual(titleParts("nme", "The best albums of 2026 so far", "", []), { album: "", artist: "", verdict: "" });
    assert.deepEqual(
      titleParts("billboard", "Ms. Rachel’s ‘I’m So Happy’: All 23 Tracks Ranked", "", []),
      { artist: "Ms. Rachel", album: "I’m So Happy", verdict: "All 23 Tracks Ranked" },
    );
    assert.equal(titleParts("billboard", "Olivia Rodrigo Rocks Out at Surprise Underplay", "", []).album, "");
    assert.deepEqual(
      titleParts("stereogum", "Willi Carlisle The Universal Bubba", "", ["Album Of The Week", "Reviews", "Tyler Childers", "Willi Carlisle"]),
      { artist: "Willi Carlisle", album: "The Universal Bubba", verdict: "" },
    );
    assert.equal(titleParts("stereogum", "DIIV ZIRP!", "", ["Album Of The Week", "Reviews"]).album, "");
    assert.deepEqual(
      titleParts("pitchfork", "On Tha Run", "https://pitchfork.com/reviews/albums/baby-osamaa-on-tha-run/", []),
      { album: "On Tha Run", artist: "Baby Osamaa", verdict: "" },
    );
    assert.equal(
      titleParts("pitchfork", "cantu of the sower EP", "https://pitchfork.com/reviews/albums/heavensouls-cantu-of-the-sower-ep/", []).artist,
      "Heavensouls",
    );
  });

  it("keeps album reviews only: headlines without an album and artist go", () => {
    const xml = `<item><title>Olivia Rodrigo Rocks Out at Surprise Underplay in Brooklyn</title>
<link>https://www.billboard.com/music/olivia/</link><pubDate>Mon, 09 Nov 2026 10:00:00 +0000</pubDate>
<category>Reviews</category></item>`;
    assert.equal(newsFromFeed(source("billboard"), xml).length, 0);
    const [krill] = newsFromFeed(source("stereogum"), stereogum);
    assert.equal(krill.album, "Secret Language");
    assert.equal(krill.artist, "Krill");
  });

  it("ids are stable across query strings and trailing slashes", () => {
    assert.equal(newsId("https://x.com/a/"), newsId("https://x.com/a?utm=1"));
    assert.match(newsId("https://x.com/a"), /^[0-9a-f]{20}$/);
  });

  it("asks each site for a smaller image", () => {
    assert.equal(
      smallImageUrl("https://media.pitchfork.com/photos/6aea/master/pass/a.jpg"),
      "https://media.pitchfork.com/photos/6aea/master/w_640,c_limit/a.jpg",
    );
    assert.equal(
      smallImageUrl("https://www.nme.com/wp-content/uploads/2026/11/U2.jpg"),
      "https://www.nme.com/wp-content/uploads/2026/11/U2.jpg?w=640",
    );
    assert.equal(
      smallImageUrl("https://lede-admin.stereogum.com/wp-content/uploads/sites/64/k.jpg?w=564"),
      "https://lede-admin.stereogum.com/wp-content/uploads/sites/64/k.jpg?w=640",
    );
    assert.equal(smallImageUrl("https://i.imgur.com/x.png"), "https://i.imgur.com/x.png");
  });
});
