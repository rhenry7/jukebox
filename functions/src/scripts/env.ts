/**
 * Loads functions/.env.<project> (the same non-secret params the deployed
 * functions get) into process.env for local scripts. Existing env vars win.
 */
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

export function loadProjectEnv(project = process.env.GCLOUD_PROJECT ?? "juxeboxd"): void {
  const file = join(__dirname, "../..", `.env.${project}`);
  if (!existsSync(file)) return;
  for (const line of readFileSync(file, "utf8").split("\n")) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
}
