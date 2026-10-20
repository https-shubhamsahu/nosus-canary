import { assertEquals, assertFalse, assertThrows } from "jsr:@std/assert@1.0.19";
import { parseRelayerKeys } from "../src/keys.ts";
import { base58Decode } from "../src/base58.ts";

// Test bytes 1..64 only; not a funded key.
const KEY = Uint8Array.from({ length: 64 }, (_, i) => i + 1);
const JSON_KEY = JSON.stringify([...KEY]);
const BASE58_KEY =
  "2Ana1pUpv2ZbMVkwF5FXapYeBEjdxDatLn7nvJkhgTSXbs59SyZSx866bXirPgj8QQVB57uxHJBG1YFvkRbFj4T";

Deno.test("base58Decode keeps leading zero bytes", () => {
  assertEquals(base58Decode(""), new Uint8Array());
  assertEquals(base58Decode("111"), new Uint8Array(3));
  assertEquals(base58Decode("11z"), Uint8Array.from([0, 0, 57]));
  assertEquals(base58Decode("5Q"), Uint8Array.from([255]));
  assertEquals(base58Decode("5R"), Uint8Array.from([1, 0]));
  assertThrows(() => base58Decode("0"), Error, "not base58");
});

Deno.test("parseRelayerKeys: base58 and solana-keygen JSON, comma-separated", () => {
  assertEquals(parseRelayerKeys(BASE58_KEY), [KEY]);
  assertEquals(parseRelayerKeys(JSON_KEY), [KEY]);
  assertEquals(parseRelayerKeys(`${JSON_KEY}, ${BASE58_KEY},${JSON_KEY}`), [KEY, KEY, KEY]);
});

Deno.test("parseRelayerKeys: errors name the problem, never the key", () => {
  const cases: [string, string][] = [
    ["", "SOLANA_RELAYER_KEYS must hold 1 to 32 keys"],
    [" , ", "SOLANA_RELAYER_KEYS must hold 1 to 32 keys"],
    [Array(33).fill(BASE58_KEY).join(","), "SOLANA_RELAYER_KEYS must hold 1 to 32 keys"],
    ["[1,2,]", "SOLANA_RELAYER_KEYS: a JSON key is not valid JSON"],
    ["[1,256]", "SOLANA_RELAYER_KEYS: a JSON key must be an array of bytes"],
    ["[1.5]", "SOLANA_RELAYER_KEYS: a JSON key must be an array of bytes"],
    [`0${BASE58_KEY}`, "SOLANA_RELAYER_KEYS: a key must be base58 or a JSON array"],
    [BASE58_KEY.slice(0, 40), "SOLANA_RELAYER_KEYS: a key must be 64 bytes"],
    [JSON.stringify([...KEY, 7]), "SOLANA_RELAYER_KEYS: a key must be 64 bytes"],
  ];
  for (const [raw, message] of cases) {
    const err = assertThrows(() => parseRelayerKeys(raw), Error);
    assertEquals(err.message, message, raw);
    assertFalse(err.message.includes(BASE58_KEY.slice(0, 8)));
  }
});
