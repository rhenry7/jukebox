import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, it } from "node:test";
import { keysChanged } from "../search";
import { MAX_TEXT_WORD_KEYS, ReviewDoc, searchKeys, SearchKeys } from "../text";

// Shared with the app's tests, so both sides build identical keys.
const fixtures = JSON.parse(
  readFileSync(join(__dirname, "../../src/__tests__/fixtures/search_keys.json"), "utf8"),
) as { name: string; review: Partial<ReviewDoc>; keys: SearchKeys }[];

describe("searchKeys", () => {
  for (const f of fixtures) {
    it(f.name, () => {
      assert.deepEqual(searchKeys(f.review), f.keys);
    });
  }

  it(`indexes at most ${MAX_TEXT_WORD_KEYS} words of long reviews`, () => {
    const text = Array.from({ length: 400 }, (_, i) => `word${i}`).join(" ");
    assert.equal(searchKeys({ review: text }).textWordKeys.length, MAX_TEXT_WORD_KEYS);
  });
});

describe("keysChanged", () => {
  const keys: SearchKeys = { tagKeys: ["r&b"], tagWordKeys: ["r&b"], textWordKeys: ["smooth"] };

  it("is false when the stored keys match, so the trigger doesn't loop", () => {
    assert.equal(keysChanged({ ...keys, title: "x" }, keys), false);
  });

  it("is true when keys are missing or differ", () => {
    assert.equal(keysChanged({}, keys), true);
    assert.equal(keysChanged({ ...keys, tagKeys: ["jazz"] }, keys), true);
  });

  it("treats missing keys as empty for reviews that index nothing", () => {
    const none: SearchKeys = { tagKeys: [], tagWordKeys: [], textWordKeys: [] };
    assert.equal(keysChanged({}, none), false);
  });
});
