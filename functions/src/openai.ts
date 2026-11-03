/** Minimal OpenAI client (fetch-based, no SDK). Server-side only. */
import { CHAT_MODEL, EMBEDDING_DIMS, EMBEDDING_MODEL } from "./config";
import { Vec } from "./vectors";

const BASE = "https://api.openai.com/v1";

async function post(apiKey: string, path: string, body: unknown, timeoutMs: number): Promise<any> {
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(`${BASE}${path}`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (res.ok) return res.json();
    const retryable = res.status === 429 || res.status >= 500;
    if (!retryable || attempt >= 1) {
      throw new Error(`OpenAI ${path} ${res.status}: ${(await res.text()).slice(0, 300)}`);
    }
    await new Promise((r) => setTimeout(r, 800));
  }
}

/** Chat completion constrained to a JSON schema; returns the parsed object. */
export async function chatJson<T>(
  apiKey: string,
  opts: { system: string; user: string; schemaName: string; schema: object; timeoutMs?: number },
): Promise<T> {
  const data = await post(
    apiKey,
    "/chat/completions",
    {
      model: CHAT_MODEL,
      temperature: 0,
      response_format: {
        type: "json_schema",
        json_schema: { name: opts.schemaName, strict: true, schema: opts.schema },
      },
      messages: [
        { role: "system", content: opts.system },
        { role: "user", content: opts.user },
      ],
    },
    opts.timeoutMs ?? 20_000,
  );
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content !== "string") throw new Error("OpenAI returned no content");
  return JSON.parse(content) as T;
}

/** Embeds texts in one request; output order matches input order. */
export async function embed(apiKey: string, texts: string[]): Promise<Vec[]> {
  if (texts.length === 0) return [];
  const data = await post(
    apiKey,
    "/embeddings",
    { model: EMBEDDING_MODEL, input: texts, dimensions: EMBEDDING_DIMS },
    20_000,
  );
  return (data.data as { index: number; embedding: Vec }[])
    .sort((a, b) => a.index - b.index)
    .map((d) => d.embedding);
}
