import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, it } from "node:test";
import { normName, parseSimilarArtists, pickArtist, pickRecording, retryDelayMs, reviewArtists } from "../musicbrainz";

const fixture = (name: string) =>
  JSON.parse(readFileSync(join(__dirname, "../../src/__tests__/fixtures", name), "utf8"));

describe("names", () => {
  it("compares names loosely", () => {
    assert.equal(normName("Beyoncé"), "beyonce");
    assert.equal(normName("Simon & Garfunkel"), normName("Simon and Garfunkel"));
    assert.equal(normName("  Anderson .Paak "), "anderson paak");
  });

  it("splits a review's artists", () => {
    assert.deepEqual(reviewArtists("Masego, FKJ"), ["masego", "fkj"]);
    assert.deepEqual(reviewArtists("Daniel Caesar feat. H.E.R."), ["daniel caesar", "h e r"]);
  });
});

describe("pickRecording (real MusicBrainz response for Tadow)", () => {
  const results = fixture("mb_recording_search.json").recordings;

  it("finds the song and all its credited artists", () => {
    const ids = pickRecording(results, "Tadow", "Masego, FKJ");
    assert.ok(ids);
    assert.equal(ids.recordingMbid, "2de8a036-52c2-446b-b152-9d0c4f25fe60");
    assert.ok(ids.artistMbids.includes("bca63b5d-a28c-4937-a8f4-e3f2d95426e1"), "Masego");
    assert.ok(ids.artistMbids.includes("8ef74994-73f6-459c-a10c-56a16e07b362"), "FKJ");
  });

  it("matches on any of the review's artists", () => {
    assert.ok(pickRecording(results, "Tadow", "FKJ"));
  });

  it("rejects a result by someone else", () => {
    assert.equal(pickRecording(results, "Tadow", "Some Cover Band"), null);
  });

  it("rejects low-confidence results", () => {
    const weak = results.map((r: { score: number }) => ({ ...r, score: 60 }));
    assert.equal(pickRecording(weak, "Tadow", "Masego"), null);
  });

  it("prefers an exact title over a higher-ranked near miss", () => {
    const credit = results[0]["artist-credit"];
    const ids = pickRecording(
      [
        { id: "live", score: 100, title: "Tadow (Live)", "artist-credit": credit },
        { id: "studio", score: 95, title: "Tadow", "artist-credit": credit },
      ],
      "Tadow",
      "Masego",
    );
    assert.equal(ids?.recordingMbid, "studio");
  });
});

describe("pickArtist", () => {
  it("needs an exact, confident name match", () => {
    const results = [
      { id: "a", score: 100, name: "Masego" },
      { id: "b", score: 100, name: "Masego Band" },
    ];
    assert.equal(pickArtist(results, "masego"), "a");
    assert.equal(pickArtist([{ id: "c", score: 70, name: "Masego" }], "Masego"), null);
  });
});

describe("parseSimilarArtists (real ListenBrainz response for Masego)", () => {
  it("returns artists best first with the best scaled to 1", () => {
    const similar = parseSimilarArtists(fixture("lb_similar_artists.json"));
    assert.equal(similar[0].name, "Anderson .Paak");
    assert.equal(similar[0].score, 1);
    for (let i = 1; i < similar.length; i++) {
      assert.ok(similar[i].score <= similar[i - 1].score);
      assert.ok(similar[i].score > 0 && similar[i].mbid.length === 36);
    }
  });

  it("handles nested lists, junk rows and a limit", () => {
    const body = [[{ artist_mbid: "x", name: "X", score: 10 }, { foo: 1 }, { artist_mbid: "y", name: "Y", score: 20 }]];
    assert.deepEqual(parseSimilarArtists(body, 1), [{ mbid: "y", name: "Y", score: 1 }]);
    assert.deepEqual(parseSimilarArtists({ error: "bad" }), []);
  });
});

describe("retryDelayMs", () => {
  it("follows Retry-After, capped at 30 s", () => {
    assert.equal(retryDelayMs(1, "3"), 3000);
    assert.equal(retryDelayMs(1, "600"), 30_000);
  });
  it("backs off 2, 4, 8 s otherwise", () => {
    assert.deepEqual([1, 2, 3].map((a) => retryDelayMs(a, null)), [2000, 4000, 8000]);
  });
});
