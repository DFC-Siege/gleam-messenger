import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const envFile = existsSync(join(root, ".env")) ? ".env" : ".env.example";

const env = Object.fromEntries(
  readFileSync(join(root, envFile), "utf8")
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"))
    .map((line) => {
      const i = line.indexOf("=");
      return [line.slice(0, i).trim(), line.slice(i + 1).trim()];
    }),
);

const origin = (env.SERVER_ORIGIN ?? "http://localhost:8000").replace(/\/+$/, "");
const wsOrigin = origin.replace(/^http/, "ws");

const apiBase = `${origin}/api/`;
const wsBase = `${wsOrigin}/ws?token=`;

const out = `// Generated from ${envFile} by scripts/gen-env.mjs — do not edit.
pub const api_base = "${apiBase}"

pub const ws_base = "${wsBase}"
`;

const target = join(root, "src", "client", "env.gleam");
writeFileSync(target, out);
console.log(`gen-env: ${envFile} (${origin}) -> src/client/env.gleam`);
