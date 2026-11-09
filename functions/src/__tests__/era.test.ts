import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { eraFit, metaTagsFor, yearFrom, yearSimilarity } from "../era";
import { pickRecording } from "../musicbrainz";

describe("era metadata", () => {
  it("reads years from MusicBrainz dates", () => {
    assert.equal(yearFrom("2017-10-06"), 2017);
    assert.equal(yearFrom("1975"), 1975);
    assert.equal(yearFrom(""), null);
    assert.equal(yearFrom(undefined), null);
    assert.equal(yearFrom("0001-01-01"), null);
  });

  it("hidden tags: decade and era", () => {
    assert.deepEqual(metaTagsFor(1975), ["decade:1970s", "era:classic"]);
    assert.deepEqual(metaTagsFor(1964), ["decade:1960s", "era:golden"]);
    assert.deepEqual(metaTagsFor(1999), ["decade:1990s", "era:modern"]);
    assert.deepEqual(metaTagsFor(2017), ["decade:2010s", "era:streaming"]);
    assert.deepEqual(metaTagsFor(1940), ["decade:1940s", "era:early"]);
    assert.deepEqual(metaTagsFor(null), []);
  });

  it("closeness falls off with the gap between years", () => {
    assert.equal(yearSimilarity(1975, 1975), 1);
    assert.ok(yearSimilarity(1975, 1979) > 0.45 && yearSimilarity(1975, 1979) < 0.55);
    assert.ok(yearSimilarity(1975, 2015) < 0.01);
    assert.equal(yearSimilarity(null, 1975), 0);
  });

  it("era fit: weighted toward the music the user loves most", () => {
    const loved = [
      { year: 1975, weight: 1 },
      { year: 2018, weight: 0.3 },
    ];
    assert.ok(eraFit(1976, loved) > eraFit(2017, loved));
    assert.equal(eraFit(null, loved), 0);
    assert.equal(eraFit(1975, []), 0);
  });

  it("takes the earliest release among a song's matching recordings", () => {
    const credit = [{ name: "Queen", artist: { id: "q", name: "Queen" } }];
    const ids = pickRecording(
      [
        { id: "remaster", score: 100, title: "Bohemian Rhapsody", "first-release-date": "2011-03-14", "artist-credit": credit },
        { id: "original", score: 95, title: "Bohemian Rhapsody", "first-release-date": "1975-10-31", "artist-credit": credit },
        { id: "other", score: 95, title: "Bohemian Rhapsody (Live)", "first-release-date": "1974", "artist-credit": credit },
      ],
      "Bohemian Rhapsody",
      "Queen",
    );
    assert.equal(ids?.releaseYear, 1975);
  });
});
