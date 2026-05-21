import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import { canonicalJson, keccak256Hex } from "../../shared/src/index.ts";

export type JsonValue = null | boolean | number | string | JsonValue[] | { [key: string]: JsonValue | undefined };
export type JsonObject = { [key: string]: JsonValue | undefined };

export const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");

export function readJson<T = JsonValue>(path: string): T {
  return JSON.parse(readFileSync(resolve(REPO_ROOT, path), "utf8")) as T;
}

export function listJson<T = JsonObject>(dir: string): T[] {
  const resolved = resolve(REPO_ROOT, dir);
  if (!existsSync(resolved)) return [];
  return readdirSync(resolved)
    .filter((name) => name.endsWith(".json"))
    .map((name) => readJson<T>(`${dir}/${name}`));
}

export function canonicalize(value: JsonValue): string {
  return canonicalJson(value);
}

export function stableHash(schema: string, value: JsonValue): `0x${string}` {
  return keccak256Hex(new TextEncoder().encode(canonicalJson({ schema, value })));
}

export function validateWithSchema<T>(schemaPath: string, input: unknown): T {
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  addFormats(ajv);
  const schema = readJson<JsonObject>(schemaPath);
  const validate = ajv.compile(schema);
  if (!validate(input)) {
    throw new Error(`Validation failed for ${schemaPath}: ${JSON.stringify(validate.errors)}`);
  }
  return input as T;
}

export function optionalString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

export function decimal(value: unknown, fallback = "0"): string {
  return typeof value === "string" && /^\d+$/.test(value) ? value : fallback;
}

export function addDecimalStrings(values: string[]): string {
  return values.reduce((total, value) => total + BigInt(value), 0n).toString();
}

export function fileExists(path: string): boolean {
  return existsSync(resolve(REPO_ROOT, path));
}

export function isPlaceholder(value: unknown): boolean {
  return typeof value === "string" && /PENDING|template/i.test(value);
}
